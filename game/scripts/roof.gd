extends Node2D
## A damaged slate roof over one building, baked into one texture. Hides the interior until
## Toa walks in, then fades out. Holes have ragged edges so it reads as broken, not cut.

const HOLE_CHANCE := 0.12

var level: Level
var index := -1
var tiles: Array[Vector2i] = []  # interior and wall cells the roof covers
var holes: Dictionary = {}
var target_alpha := 1.0


func setup(lvl: Level, interior: Array, idx: int) -> void:
	level = lvl
	index = idx
	var seen := {}
	for c in interior:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dy)
				if seen.has(n):
					continue
				if n == c or level.in_bounds(n) and level.is_wall(n):
					seen[n] = true
					tiles.append(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 7919 + 13
	for c in tiles:
		if rng.randf() < HOLE_CHANCE:
			holes[c] = true
	z_index = 5
	_bake(seen, rng)


func _bake(covered: Dictionary, rng: RandomNumberGenerator) -> void:
	var lo := tiles[0]
	var hi := tiles[0]
	for c in tiles:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var art := PixelArt.T
	var img := Image.create_empty((hi.x - lo.x + 1) * art, (hi.y - lo.y + 1) * art, false, Image.FORMAT_RGBA8)
	for c in tiles:
		if holes.has(c):
			continue
		var n := int(Level._noise(c.x * 3, c.y * 5) * 255.0)
		var dst := (c - lo) * art
		img.blit_rect(PixelArt.tile("roof", 2 if n % 9 == 0 else n % 2), Rect2i(0, 0, art, art), dst)
		# Dark eaves along the outer edge, ragged bites next to holes.
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nb: Vector2i = c + d
			var edge := Rect2i(dst.x + (art - 2 if d.x > 0 else 0), dst.y + (art - 2 if d.y > 0 else 0),
				art if d.x == 0 else 2, art if d.y == 0 else 2)
			if not covered.has(nb):
				img.fill_rect(edge, Color8(30, 32, 38))
			elif holes.has(nb):
				for i in 6:
					var px := edge.position + Vector2i(rng.randi() % edge.size.x, rng.randi() % edge.size.y)
					var depth := rng.randi_range(1, 3)
					img.fill_rect(Rect2i(px - Vector2i(maxi(0, d.x), maxi(0, d.y)) * (depth - 1), Vector2i(1, 1) + Vector2i(absi(d.x), absi(d.y)) * (depth - 1)), Color(0, 0, 0, 0))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.scale = Vector2.ONE * (Level.CELL / float(art))
	spr.position = Vector2(lo) * Level.CELL
	spr.light_mask = 2  # world lights do not light roofs; only the moonlight modulate does
	add_child(spr)


func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a, target_alpha, delta * 4.0)
