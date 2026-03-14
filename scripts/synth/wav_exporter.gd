class_name WavExporter
extends RefCounted
## Converts audio buffers to 16-bit PCM WAV and saves to disk.
## Supports both mono and stereo (interleaved) formats.

const SAMPLE_RATE: int = 44100
const BITS_PER_SAMPLE: int = 16


static func save_wav(buffer: PackedFloat32Array, file_path: String, channels: int = 1) -> int:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE

	var num_samples: int = buffer.size()
	var block_align: int = channels * BITS_PER_SAMPLE / 8
	var byte_rate: int = SAMPLE_RATE * block_align
	var data_size: int = num_samples * BITS_PER_SAMPLE / 8

	# RIFF header
	file.store_string("RIFF")
	file.store_32(36 + data_size)  # File size - 8
	file.store_string("WAVE")

	# fmt subchunk
	file.store_string("fmt ")
	file.store_32(16)              # Subchunk1 size (PCM)
	file.store_16(1)               # Audio format (1 = PCM)
	file.store_16(channels)
	file.store_32(SAMPLE_RATE)
	file.store_32(byte_rate)
	file.store_16(block_align)
	file.store_16(BITS_PER_SAMPLE)

	# data subchunk
	file.store_string("data")
	file.store_32(data_size)

	# Write samples as 16-bit signed integers
	for i in num_samples:
		var sample: float = clampf(buffer[i], -1.0, 1.0)
		var int_sample: int = int(sample * 32767.0)
		file.store_16(int_sample)

	return OK


## Save stereo interleaved buffer [L0, R0, L1, R1, ...] as stereo WAV
static func save_wav_stereo(interleaved: PackedFloat32Array, file_path: String) -> int:
	return save_wav(interleaved, file_path, 2)
