extends Node2D
## A damaged roof over one building. Hides the interior until Toa walks in, then fades out.

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
				if n == c or level.is_wall(n) and level.in_bounds(n):
					seen[n] = true
					tiles.append(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 7919 + 13
	for c in tiles:
		if rng.randf() < HOLE_CHANCE:
			holes[c] = true
	z_index = 5
	light_mask = 2  # world lights do not light roofs; only the moonlight modulate does


func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a, target_alpha, delta * 4.0)


func _draw() -> void:
	var cell := float(Level.CELL)
	for c in tiles:
		if holes.has(c):
			continue
		var r := Rect2(Vector2(c) * cell, Vector2(cell, cell))
		var n := Level._noise(c.x * 3, c.y * 5)
		draw_rect(r, Color(0.2, 0.21, 0.24).lerp(Color(0.24, 0.25, 0.28), n))
		draw_line(r.position + Vector2(0, 10), r.position + Vector2(cell, 10), Color(0.15, 0.16, 0.18), 1.0)
		draw_line(r.position + Vector2(0, 21), r.position + Vector2(cell, 21), Color(0.15, 0.16, 0.18), 1.0)
		if n > 0.85:
			draw_rect(Rect2(r.position + Vector2(6, 4), Vector2(10, 6)), Color(0.32, 0.22, 0.18))
