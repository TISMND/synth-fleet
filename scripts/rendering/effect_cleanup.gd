class_name EffectCleanup
extends GPUParticles2D
## Auto-frees one-shot particle effects after their lifetime expires.

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime + 0.1)
	timer.timeout.connect(queue_free)


## Set the particle color via the process material.
func set_color(c: Color) -> void:
	var mat := process_material as ParticleProcessMaterial
	if mat:
		mat = mat.duplicate() as ParticleProcessMaterial
		mat.color = c
		process_material = mat
