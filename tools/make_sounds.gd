extends SceneTree
## Synthesizes every sound in the game and saves them as WAV files in
## res://sounds (mono, 22 050 Hz). Run once after changing a sound:
##   godot --headless --path . -s res://tools/make_sounds.gd
## Nothing is recorded or licensed: plucks are Karplus-Strong strings, chimes
## are a few decaying sine partials, the drone is soft sines, wind and water
## are shaped noise, birds are swept whistles. Loops are cross-faded so they
## repeat without a click.

const RATE := 22050
const DIR := "res://sounds/"
# D major pentatonic, the folk scale of The Lowlands: D E F# A B.
const PLUCK_NOTES := {
	"pluck_d3": 146.83, "pluck_e3": 164.81, "pluck_fs3": 185.0, "pluck_a3": 220.0, "pluck_b3": 246.94,
	"pluck_d4": 293.66, "pluck_e4": 329.63, "pluck_fs4": 369.99, "pluck_a4": 440.0, "pluck_b4": 493.88,
	"pluck_d5": 587.33,
}
const CHIME_NOTES := {
	"chime_1": 587.33, "chime_2": 659.26, "chime_3": 739.99, "chime_4": 880.0, "chime_5": 987.77, "chime_6": 1174.66,
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 2026
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for name: String in PLUCK_NOTES:
		_save(name, _pluck(PLUCK_NOTES[name], 1.6))
	for name: String in CHIME_NOTES:
		_save(name, _chime(CHIME_NOTES[name], 1.6))
	_save("drone", _loop(func(n: int) -> PackedFloat32Array: return _drone(n), 8.0))
	_save("wind", _loop(func(n: int) -> PackedFloat32Array: return _wind(n), 8.0))
	_save("water", _loop(func(n: int) -> PackedFloat32Array: return _water(n), 8.0))
	_save("meadow", _loop(func(n: int) -> PackedFloat32Array: return _meadow(n), 8.0))
	for i in 4:
		_save("bird_%d" % i, _bird(i))
	_save("place", _place())
	_save("owl", _owl())
	_save("squeak", _squeak())
	_save("whistle", _whistle())
	print("sounds written to ", ProjectSettings.globalize_path(DIR))
	quit()


func _save(name: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(DIR + name + ".wav")


## A plucked string (Karplus-Strong): a burst of noise in a delay line that
## averages itself down, like a guitar or harp string.
func _pluck(freq: float, seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var period := int(RATE / freq)
	var buf := PackedFloat32Array()
	buf.resize(period)
	for i in period:
		buf[i] = rng.randf_range(-1.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var idx := 0
	var decay := 0.996
	for i in n:
		var a := buf[idx]
		var b := buf[(idx + 1) % period]
		var v := (a + b) * 0.5 * decay
		buf[idx] = v
		out[i] = a * 0.55
		idx = (idx + 1) % period
	_fade_out(out, 0.25)
	return out


## A soft chime: a few inharmonic sine partials that ring and fade.
func _chime(freq: float, seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[1.0, 1.0, 2.2], [2.76, 0.35, 4.0], [5.4, 0.15, 7.0]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p: Array in partials:
			v += sin(TAU * freq * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]))
		var attack := minf(t / 0.005, 1.0)
		out[i] = v * 0.32 * attack
	return out


## Builds a seamless loop: makes `seconds` plus a little extra, then blends
## the extra into the start.
func _loop(make: Callable, seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var fade := int(0.6 * RATE)
	var raw: PackedFloat32Array = make.call(n + fade)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		out[i] = raw[n + i] * (1.0 - w) + raw[i] * w
	return out


## A low drone on D and A, slowly breathing.
func _drone(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var swell := 0.75 + 0.25 * sin(TAU * t / 8.0)
		var v := sin(TAU * 73.5 * t) * 0.5 + sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 147.0 * t) * 0.12
		out[i] = v * 0.22 * swell
	return out


## Wind over heather: brown noise with slow gusts.
func _wind(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = clampf(brown + rng.randf_range(-0.02, 0.02), -1.0, 1.0) * 0.999
		lp += (brown - lp) * 0.08
		var gust := 0.55 + 0.45 * sin(TAU * t / 5.3) * sin(TAU * t / 2.9 + 1.0)
		out[i] = lp * 0.42 * gust
	return out


## A brook: brighter noise with quick bubbling.
func _water(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp_prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.25
		var hp := lp - hp_prev
		hp_prev = lp
		var bubble := 0.6 + 0.4 * sin(TAU * (7.0 + 3.0 * sin(TAU * t * 0.7)) * t)
		out[i] = (lp * 0.35 + hp * 0.5) * bubble * 0.5
	return out


## Summer meadow: a soft insect hum that comes and goes.
func _meadow(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 210.0 + 12.0 * sin(TAU * t * 4.3)
		phase += f / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		lp += (saw - lp) * 0.06
		var swell := maxf(0.0, sin(TAU * t / 4.0)) * 0.8 + 0.2
		out[i] = lp * 0.25 * swell
	return out


## Bird calls: short swept whistles with a little warble.
func _bird(kind: int) -> PackedFloat32Array:
	var notes := [[2400.0, 3200.0, 0.12], [3100.0, 2300.0, 0.1], [2800.0, 3600.0, 0.07], [2000.0, 2600.0, 0.16]]
	var out := PackedFloat32Array()
	var reps: int = [3, 2, 4, 2][kind]
	for r in reps:
		var nt: Array = notes[kind]
		var len := int(float(nt[2]) * RATE)
		var phase := 0.0
		for i in len:
			var k := float(i) / len
			var f := lerpf(nt[0], nt[1], k) + 120.0 * sin(TAU * 30.0 * k)
			phase += f / RATE
			var env := sin(PI * k)
			out.append(sin(TAU * phase) * env * 0.35)
		for i in int(0.05 * RATE):
			out.append(0.0)
	return out


## A piece landing: a soft fabric rustle over a low, felt thump.
func _place() -> PackedFloat32Array:
	var n := int(0.32 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var rustle := lp * exp(-t * 14.0) * 0.5
		var thump := sin(TAU * 95.0 * t) * exp(-t * 28.0) * 0.6
		out[i] = rustle + thump
	return out


## An owl's two soft hoots.
func _owl() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for hoot: Array in [[0.32, 390.0], [0.55, 360.0]]:
		var len := int(float(hoot[0]) * RATE)
		for i in len:
			var k := float(i) / len
			var t := float(i) / RATE
			var f := float(hoot[1]) * (1.0 + 0.04 * sin(TAU * 6.0 * t))
			out.append(sin(TAU * f * t) * sin(PI * k) * 0.4)
		for i in int(0.12 * RATE):
			out.append(0.0)
	return out


## A small creature's chirrup (otters, hedgehogs, dormice...).
func _squeak() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for r in 3:
		var len := int(0.07 * RATE)
		var phase := 0.0
		for i in len:
			var k := float(i) / len
			phase += lerpf(1500.0, 2300.0, k) / RATE
			out.append(sin(TAU * phase) * sin(PI * k) * 0.3)
		for i in int(0.04 * RATE):
			out.append(0.0)
	return out


## A long falling whistle (eagles, herons and other big birds).
func _whistle() -> PackedFloat32Array:
	var len := int(0.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(len)
	var phase := 0.0
	for i in len:
		var k := float(i) / len
		phase += lerpf(2600.0, 1500.0, k * k) / RATE
		out[i] = sin(TAU * phase) * sin(PI * k) * 0.3
	return out


func _fade_out(a: PackedFloat32Array, seconds: float) -> void:
	var n := mini(int(seconds * RATE), a.size())
	for i in n:
		a[a.size() - n + i] *= 1.0 - float(i) / n
