class_name Projectile
extends Area2D
## A single projectile. Moves in a direction, deals damage on contact, despawns offscreen.

@export var speed: float = 600.0
@export var damage: int = 10

var direction: Vector2 = Vector2.UP
var neon_color: Color = Color(0, 1, 1)
var effect_profile: EffectProfile = null

var _impact_scene: PackedScene
var _ring_effect_scene: PackedScene
var _shatter_effect_scene: PackedScene
var _nova_effect_scene: PackedScene


func _ready() -> void:
	_impact_scene = preload("res://scenes/effects/impact_burst.tscn")
	_ring_effect_scene = preload("res://scenes/effects/ring_effect.tscn")
	_shatter_effect_scene = preload("res://scenes/effects/shatter_effect.tscn")
	_nova_effect_scene = preload("res://scenes/effects/nova_effect.tscn")
	body_entered.connect(_on_body_entered)
	# Auto-despawn after leaving screen
	var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
	notifier.screen_exited.connect(queue_free)

	# Apply effect profile if set
	if effect_profile:
		_apply_effect_profile()
	else:
		_apply_default_visuals()


func _apply_default_visuals() -> void:
	# Original behavior
	var neon := $NeonSprite as NeonShape2D
	if neon:
		neon.color = neon_color
	var trail := $Trail as GPUParticles2D
	if trail:
		var mat := trail.process_material as ParticleProcessMaterial
		if mat:
			mat = mat.duplicate() as ParticleProcessMaterial
			mat.color = Color(neon_color.r, neon_color.g, neon_color.b, 0.6)
			trail.process_material = mat


func _apply_effect_profile() -> void:
	# Shape
	var neon := $NeonSprite as NeonShape2D
	if neon:
		neon.color = neon_color
		neon.points = effect_profile.get_shape_points()
		var sp := effect_profile.shape_params
		var glow_defaults := EffectProfile.get_shape_glow_defaults()
		neon.glow_width = sp.get("glow_width", glow_defaults["glow_width"])
		neon.glow_intensity = sp.get("glow_intensity", glow_defaults["glow_intensity"])
		neon.core_brightness = sp.get("core_brightness", glow_defaults["core_brightness"])
		neon.pass_count = int(sp.get("pass_count", glow_defaults["pass_count"]))
	# Update collision shape to match new points
	var col := $CollisionShape2D as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		var pts := effect_profile.get_shape_points()
		var min_pt := Vector2(INF, INF)
		var max_pt := Vector2(-INF, -INF)
		for p in pts:
			min_pt.x = minf(min_pt.x, p.x)
			min_pt.y = minf(min_pt.y, p.y)
			max_pt.x = maxf(max_pt.x, p.x)
			max_pt.y = maxf(max_pt.y, p.y)
		var rect_shape := col.shape.duplicate() as RectangleShape2D
		rect_shape.size = max_pt - min_pt
		col.shape = rect_shape

	# Trail
	var default_trail := $Trail as GPUParticles2D
	match effect_profile.trail_type:
		"none":
			if default_trail:
				default_trail.visible = false
				default_trail.emitting = false
		"particle":
			if default_trail:
				var tp := effect_profile.trail_params
				var td := EffectProfile.get_trail_defaults("particle")
				default_trail.amount = int(tp.get("amount", td["amount"]))
				default_trail.lifetime = tp.get("lifetime", td["lifetime"])
				var mat := default_trail.process_material as ParticleProcessMaterial
				if mat:
					mat = mat.duplicate() as ParticleProcessMaterial
					mat.color = Color(neon_color.r, neon_color.g, neon_color.b, 0.6)
					mat.spread = tp.get("spread", td["spread"])
					mat.initial_velocity_max = tp.get("velocity_max", td["velocity_max"])
					mat.initial_velocity_min = mat.initial_velocity_max * 0.5
					default_trail.process_material = mat
		"ribbon":
			if default_trail:
				default_trail.visible = false
				default_trail.emitting = false
			var tp := effect_profile.trail_params
			var td := EffectProfile.get_trail_defaults("ribbon")
			var ribbon := RibbonTrail.new()
			ribbon.trail_length = int(tp.get("length", td["length"]))
			ribbon.width_start = tp.get("width_start", td["width_start"])
			ribbon.width_end = tp.get("width_end", td["width_end"])
			ribbon.set_color(neon_color)
			add_child(ribbon)
		"afterimage":
			if default_trail:
				default_trail.visible = false
				default_trail.emitting = false
			var tp := effect_profile.trail_params
			var td := EffectProfile.get_trail_defaults("afterimage")
			var afterimg := AfterimageTrail.new()
			afterimg.afterimage_count = int(tp.get("count", td["count"]))
			afterimg.spacing_frames = int(tp.get("spacing_frames", td["spacing_frames"]))
			afterimg.fade_speed = tp.get("fade_speed", td["fade_speed"])
			afterimg.shape_points = effect_profile.get_shape_points()
			afterimg.set_color(neon_color)
			add_child(afterimg)
		"sparkle":
			if default_trail:
				var tp := effect_profile.trail_params
				var td := EffectProfile.get_trail_defaults("sparkle")
				default_trail.amount = int(tp.get("amount", td["amount"]))
				default_trail.lifetime = tp.get("lifetime", td["lifetime"])
				var mat := default_trail.process_material as ParticleProcessMaterial
				if mat:
					mat = mat.duplicate() as ParticleProcessMaterial
					mat.color = Color(neon_color.r, neon_color.g, neon_color.b, 0.6)
					mat.spread = 180.0  # Full spread for sparkle
					mat.initial_velocity_max = tp.get("velocity_max", td["velocity_max"])
					mat.initial_velocity_min = mat.initial_velocity_max * 0.3
					mat.scale_min = 0.3
					mat.scale_max = 0.8
					default_trail.process_material = mat


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_spawn_impact()
	queue_free()


func _spawn_impact() -> void:
	if effect_profile:
		_spawn_profile_impact()
		return
	var impact := _impact_scene.instantiate() as GPUParticles2D
	impact.global_position = global_position
	if impact.has_method("set_color"):
		impact.set_color(neon_color)
	get_tree().current_scene.add_child(impact)


func _spawn_profile_impact() -> void:
	var impact_type := effect_profile.impact_type
	if impact_type == "none":
		return
	var ip := effect_profile.impact_params

	match impact_type:
		"burst":
			var id := EffectProfile.get_impact_defaults("burst")
			var impact := _impact_scene.instantiate() as GPUParticles2D
			impact.global_position = global_position
			impact.amount = int(ip.get("particle_count", id["particle_count"]))
			impact.lifetime = ip.get("lifetime", id["lifetime"])
			var mat := impact.process_material as ParticleProcessMaterial
			if mat:
				mat = mat.duplicate() as ParticleProcessMaterial
				mat.color = neon_color
				mat.initial_velocity_max = ip.get("velocity_max", id["velocity_max"])
				mat.initial_velocity_min = mat.initial_velocity_max * 0.4
				impact.process_material = mat
			get_tree().current_scene.add_child(impact)
		"ring_expand":
			var id := EffectProfile.get_impact_defaults("ring_expand")
			var ring := _ring_effect_scene.instantiate() as RingEffect
			ring.global_position = global_position
			ring.radius_end = ip.get("radius_end", id["radius_end"])
			ring.lifetime = ip.get("lifetime", id["lifetime"])
			ring.segments = int(ip.get("segments", id["segments"]))
			ring.set_color(neon_color)
			get_tree().current_scene.add_child(ring)
		"shatter_lines":
			var id := EffectProfile.get_impact_defaults("shatter_lines")
			var shatter := _shatter_effect_scene.instantiate() as ShatterEffect
			shatter.global_position = global_position
			shatter.line_count = int(ip.get("line_count", id["line_count"]))
			shatter.line_length = ip.get("line_length", id["line_length"])
			shatter.lifetime = ip.get("lifetime", id["lifetime"])
			shatter.velocity = ip.get("velocity", id["velocity"])
			shatter.set_color(neon_color)
			get_tree().current_scene.add_child(shatter)
		"nova_flash":
			var id := EffectProfile.get_impact_defaults("nova_flash")
			var nova := _nova_effect_scene.instantiate() as NovaEffect
			nova.global_position = global_position
			nova.radius = ip.get("radius", id["radius"])
			nova.lifetime = ip.get("lifetime", id["lifetime"])
			nova.intensity = ip.get("intensity", id["intensity"])
			nova.set_color(neon_color)
			get_tree().current_scene.add_child(nova)
