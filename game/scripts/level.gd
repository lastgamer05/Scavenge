class_name Level
extends Node2D
## Parses an ASCII map, builds wall collision, draws the floor and answers path queries.

const CELL := 32
const ENEMY_CHARS := {"E": "pistol", "F": "smg", "G": "shotgun", "H": "bat"}
const PICKUP_CHARS := {"p": "pistol", "q": "silenced", "s": "smg", "g": "shotgun",
	"r": "rifle", "b": "bat", "k": "knife"}
const ExtractGlow := preload("res://scripts/extract_glow.gd")

var rows: Array[String] = []
var width := 0
var height := 0
var player_cell := Vector2i.ONE
var enemy_spawns: Array = []  # [Vector2i, weapon_id]
var pickup_spawns: Array = []  # [Vector2i, weapon_id]
var extract_cells: Array[Vector2i] = []
var astar := AStarGrid2D.new()


func load_from_file(path: String) -> void:
	load_from_text(FileAccess.get_file_as_string(path))


func load_from_text(text: String) -> void:
	rows.clear()
	enemy_spawns.clear()
	pickup_spawns.clear()
	extract_cells.clear()
	width = 0
	for line in text.replace("\r", "").split("\n"):
		if line.strip_edges() == "":
			continue
		rows.append(line)
		width = maxi(width, line.length())
	height = rows.size()
	for y in height:
		var row := rows[y].rpad(width, "#")
		var out := ""
		for x in width:
			var c := row[x]
			var cell := Vector2i(x, y)
			if c == "P":
				player_cell = cell
				c = _floor_near(row, x)
			elif ENEMY_CHARS.has(c):
				enemy_spawns.append([cell, ENEMY_CHARS[c]])
				c = _floor_near(row, x)
			elif PICKUP_CHARS.has(c):
				pickup_spawns.append([cell, PICKUP_CHARS[c]])
				c = _floor_near(row, x)
			elif c == "X":
				extract_cells.append(cell)
			out += c
		rows[y] = out
	_build_astar()


func _floor_near(row: String, x: int) -> String:
	for nx in [x - 1, x + 1]:
		if nx >= 0 and nx < row.length() and row[nx] == ".":
			return "."
	return ","


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = Vector2(CELL, CELL) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			if rows[y][x] == "#":
				astar.set_point_solid(Vector2i(x, y), true)


## Creates wall collision and the extraction marker. Call after adding to the tree.
func build() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in height:
		var x := 0
		while x < width:
			if rows[y][x] != "#":
				x += 1
				continue
			var start := x
			while x < width and rows[y][x] == "#":
				x += 1
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x - start) * CELL, CELL)
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = Vector2((start + x) * CELL * 0.5, y * CELL + CELL * 0.5)
			body.add_child(cs)
	var glow := ExtractGlow.new()
	glow.cells = extract_cells
	add_child(glow)
	queue_redraw()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func is_wall(c: Vector2i) -> bool:
	return not in_bounds(c) or rows[c.y][c.x] == "#"


func is_extract(c: Vector2i) -> bool:
	return in_bounds(c) and rows[c.y][c.x] == "X"


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if is_wall(a) or is_wall(b):
		return PackedVector2Array()
	return astar.get_point_path(a, b, true)


func random_floor_near(p: Vector2, radius: int) -> Vector2:
	var base := world_to_cell(p)
	for i in 12:
		var c := base + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if not is_wall(c):
			return cell_to_world(c)
	return p


func _draw() -> void:
	for y in height:
		for x in width:
			var r := Rect2(x * CELL, y * CELL, CELL, CELL)
			var c := rows[y][x]
			match c:
				"#":
					draw_rect(r, Color(0.09, 0.09, 0.11))
					if y + 1 < height and rows[y + 1][x] != "#":
						draw_rect(Rect2(r.position + Vector2(0, CELL - 6), Vector2(CELL, 6)), Color(0.05, 0.05, 0.06))
					if y > 0 and rows[y - 1][x] != "#":
						draw_rect(Rect2(r.position, Vector2(CELL, 3)), Color(0.24, 0.24, 0.28))
				".":
					var even := (x + y) % 2 == 0
					draw_rect(r, Color(0.3, 0.25, 0.2) if even else Color(0.27, 0.22, 0.18))
				_:
					var n := float(((x * 73856093) ^ (y * 19349663)) & 0xff) / 255.0
					draw_rect(r, Color(0.155, 0.17, 0.135).lerp(Color(0.175, 0.19, 0.145), n))
