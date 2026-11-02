class_name Level
extends Node2D
## Parses an ASCII map, builds wall collision and light occluders, draws the ground,
## finds buildings for roofs and answers path queries.

const CELL := 32
const ENEMY_CHARS := {"E": "pistol", "F": "smg", "G": "shotgun", "H": "bat"}
const PICKUP_CHARS := {"p": "pistol", "q": "silenced", "s": "smg", "g": "shotgun",
	"r": "rifle", "b": "bat", "k": "knife"}
const CONTAINER_CHARS := {"c": "crate", "l": "locker", "v": "safe"}
const EXTRACT_CHARS := {"X": "gate", "M": "sewer", "Z": "flare", "V": "car"}
const FLOOR_CHARS := ".,=%"
const Roof := preload("res://scripts/roof.gd")

var rows: Array[String] = []
var width := 0
var height := 0
var player_cells: Array[Vector2i] = []
var player_cell := Vector2i.ONE
var enemy_spawns: Array = []  # [Vector2i, weapon_id]
var pickup_spawns: Array = []  # [Vector2i, weapon_id]
var container_spawns: Array = []  # [Vector2i, kind]
var lamp_cells: Array[Vector2i] = []
var fire_cells: Array[Vector2i] = []
var extract_cells: Array[Vector2i] = []
var extract_groups: Dictionary = {}  # kind -> Array of cells
var buildings: Array = []  # each Array of interior cells
var cell_building: Dictionary = {}  # Vector2i -> building index
var roofs: Array = []
var astar := AStarGrid2D.new()


func load_from_file(path: String) -> void:
	load_from_text(FileAccess.get_file_as_string(path))


func load_from_text(text: String) -> void:
	rows.clear()
	player_cells.clear()
	enemy_spawns.clear()
	pickup_spawns.clear()
	container_spawns.clear()
	lamp_cells.clear()
	fire_cells.clear()
	extract_cells.clear()
	extract_groups.clear()
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
			if FLOOR_CHARS.contains(c) or c == "#":
				out += c
				continue
			if c == "P":
				player_cells.append(cell)
			elif ENEMY_CHARS.has(c):
				enemy_spawns.append([cell, ENEMY_CHARS[c]])
			elif PICKUP_CHARS.has(c):
				pickup_spawns.append([cell, PICKUP_CHARS[c]])
			elif CONTAINER_CHARS.has(c):
				container_spawns.append([cell, CONTAINER_CHARS[c]])
			elif c == "L":
				lamp_cells.append(cell)
			elif c == "f":
				fire_cells.append(cell)
			elif EXTRACT_CHARS.has(c):
				extract_cells.append(cell)
				var kind: String = EXTRACT_CHARS[c]
				if not extract_groups.has(kind):
					extract_groups[kind] = []
				extract_groups[kind].append(cell)
				out += c
				continue
			out += _floor_near(row, x)
		rows[y] = out
	if not player_cells.is_empty():
		player_cell = player_cells[0]
	_build_astar()
	_find_buildings()


func _floor_near(row: String, x: int) -> String:
	for kind in [".", "="]:
		for nx in [x - 1, x + 1]:
			if nx >= 0 and nx < row.length() and row[nx] == kind:
				return kind
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


## Buildings are connected areas of indoor floor ('.').
func _find_buildings() -> void:
	buildings.clear()
	cell_building.clear()
	for y in height:
		for x in width:
			var start := Vector2i(x, y)
			if rows[y][x] != "." or cell_building.has(start):
				continue
			var idx := buildings.size()
			var cells: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			cell_building[start] = idx
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				cells.append(c)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = c + d
					if in_bounds(n) and rows[n.y][n.x] == "." and not cell_building.has(n):
						cell_building[n] = idx
						stack.append(n)
			buildings.append(cells)


## Creates wall collision, light occluders and roofs. Call after adding to the tree.
func build(roof_parent: Node) -> void:
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
			var r := Rect2(start * CELL, y * CELL, (x - start) * CELL, CELL)
			var shape := RectangleShape2D.new()
			shape.size = r.size
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = r.get_center()
			body.add_child(cs)
			var occ := LightOccluder2D.new()
			occ.occluder = OccluderPolygon2D.new()
			occ.occluder.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			add_child(occ)
	for i in buildings.size():
		var roof := Roof.new()
		roof.setup(self, buildings[i], i)
		roof_parent.add_child(roof)
		roofs.append(roof)
	queue_redraw()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func is_wall(c: Vector2i) -> bool:
	return not in_bounds(c) or rows[c.y][c.x] == "#"


func is_extract(c: Vector2i) -> bool:
	return in_bounds(c) and EXTRACT_CHARS.has(rows[c.y][c.x])


func is_indoor(c: Vector2i) -> bool:
	return cell_building.has(c)


## Building index for a cell, or -1 outdoors.
func building_at(c: Vector2i) -> int:
	return cell_building.get(c, -1)


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


func random_edge_floor() -> Vector2:
	for i in 50:
		var c := Vector2i(randi_range(1, width - 2), [1, height - 2].pick_random())
		if randf() < 0.5:
			c = Vector2i([1, width - 2].pick_random(), randi_range(1, height - 2))
		if not is_wall(c) and not is_extract(c):
			return cell_to_world(c)
	return cell_to_world(player_cell)


static func _noise(x: int, y: int) -> float:
	return float(((x * 73856093) ^ (y * 19349663)) & 0xff) / 255.0


func _draw() -> void:
	for y in height:
		for x in width:
			var r := Rect2(x * CELL, y * CELL, CELL, CELL)
			var n := _noise(x, y)
			match rows[y][x]:
				"#":
					draw_rect(r, Color(0.2, 0.13, 0.11).lerp(Color(0.25, 0.16, 0.13), n))
					if y + 1 < height and rows[y + 1][x] != "#":
						draw_rect(Rect2(r.position + Vector2(0, CELL - 7), Vector2(CELL, 7)), Color(0.11, 0.07, 0.06))
					if y > 0 and rows[y - 1][x] != "#":
						draw_rect(Rect2(r.position, Vector2(CELL, 3)), Color(0.36, 0.25, 0.2))
					draw_line(r.position + Vector2(0, 12), r.position + Vector2(CELL, 12), Color(0.14, 0.09, 0.08), 1.0)
				".":
					var plank := Color(0.34, 0.26, 0.18) if (y % 2 == 0) else Color(0.31, 0.23, 0.16)
					draw_rect(r, plank.lerp(Color(0.26, 0.2, 0.15), n * 0.5))
					draw_line(r.position + Vector2(0, CELL - 1), r.position + Vector2(CELL, CELL - 1), Color(0.2, 0.15, 0.11), 1.0)
					draw_line(r.position + Vector2(int(n * 24) + 4, 0), r.position + Vector2(int(n * 24) + 4, CELL), Color(0.22, 0.16, 0.12), 1.0)
				"=":
					draw_rect(r, Color(0.27, 0.27, 0.29).lerp(Color(0.31, 0.31, 0.33), n))
					for i in 4:
						var off := Vector2((i % 2) * 16 + (8 if (i / 2 + y) % 2 else 0), (i / 2) * 16)
						draw_rect(Rect2(r.position + off + Vector2(1, 1), Vector2(14, 14)), Color(0.22, 0.22, 0.24), false, 1.0)
				"%":
					draw_rect(r, Color(0.2, 0.19, 0.17))
					for i in 3:
						var p := r.position + Vector2(_noise(x + i, y) * 24, _noise(x, y + i) * 24)
						draw_rect(Rect2(p, Vector2(6, 4)), Color(0.33, 0.24, 0.2) if i % 2 else Color(0.3, 0.3, 0.3))
				"X", "M", "Z", "V":
					draw_rect(r, Color(0.2, 0.22, 0.2))
				_:
					draw_rect(r, Color(0.17, 0.17, 0.15).lerp(Color(0.21, 0.2, 0.17), n))
