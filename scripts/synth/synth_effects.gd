class_name SynthEffects
extends RefCounted
## Post-render effects chain: chorus → drive/saturation → output.
## Processes stereo buffers (separate L/R PackedFloat32Arrays).

var chorus: SynthChorus
var drive: float = 0.0  # 0-1, post-filter saturation


func init(sample_rate: float) -> void:
	chorus = SynthChorus.new()
	chorus.init(sample_rate)


func process_stereo(left: PackedFloat32Array, right: PackedFloat32Array) -> void:
	# Chorus
	if chorus and chorus.mix > 0.001:
		chorus.process_stereo(left, right)

	# Post-chain saturation/drive
	if drive > 0.001:
		var gain: float = 1.0 + drive * 4.0
		for i in left.size():
			left[i] = tanh(left[i] * gain)
			right[i] = tanh(right[i] * gain)
