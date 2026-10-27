class_name Piece
extends RefCounted
## Helpers for trefoil pieces. A piece is an Array of three biome ids, in the
## plot's slot order (see PlotGrid.OFFSETS). Turning the piece 120° shifts
## the biomes one slot along; mirroring swaps slots 1 and 2 (a reflection
## across the axis through slot 0 and the confluence), so the shape never
## changes.

const DISTINCT := "distinct"
const DOUBLE := "double"
const SINGLE := "single"


static func arrange(biomes: Array, rotation: int, mirrored: bool) -> Array:
	var b := biomes.duplicate()
	if mirrored:
		var t: Variant = b[1]
		b[1] = b[2]
		b[2] = t
	var out := []
	for i in 3:
		out.append(b[posmod(i - rotation, 3)])
	return out


## Every visibly different arrangement: 6 for three different biomes,
## 3 for a double, 1 for a single.
static func distinct_arrangements(biomes: Array) -> Array:
	var out := []
	for mirrored in [false, true]:
		for rotation in 3:
			var a := arrange(biomes, rotation, mirrored)
			if not out.has(a):
				out.append(a)
	return out


static func kind(biomes: Array) -> String:
	var unique := {}
	for b in biomes:
		unique[b] = true
	match unique.size():
		3:
			return DISTINCT
		2:
			return DOUBLE
	return SINGLE


static func same_biomes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var x := a.duplicate()
	var y := b.duplicate()
	x.sort()
	y.sort()
	return x == y
