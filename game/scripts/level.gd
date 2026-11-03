class_name Level
extends Node2D
## Parses an ASCII map, builds wall collision and light occluders, draws the ground,
## finds buildings for roofs and answers path queries.

const CELL := 32
const ENEMY_CHARS := {"E": "pistol", "F": "smg", "G": "shotgun", "H": "bat", "R": "rifle"}
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


## Wall cells merged into as few rectangles as possible (row runs stacked downward).
func wall_rects() -> Array[Rect2i]:
	var done: Array[Rect2i] = []
	var open := {}  # Vector2i(x0, x1) -> Rect2i still growing
	for y in height + 1:
		var runs := {}
		var x := 0
		while y < height and x < width:
			if rows[y][x] != "#":
				x += 1
				continue
			var start := x
			while x < width and rows[y][x] == "#":
				x += 1
			runs[Vector2i(start, x)] = true
		var next := {}
		for span in runs:
			if open.has(span):
				var r: Rect2i = open[span]
				r.size.y += 1
				next[span] = r
			else:
				next[span] = Rect2i(span.x, y, span.y - span.x, 1)
		for span in open:
			if not next.has(span):
				done.append(open[span])
		open = next
	return done


## Creates wall collision, light occluders, baked ground art and roofs. Call after adding to the tree.
func build(roof_parent: Node) -> void:
	_bake()
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for cells in wall_rects():
		var r := Rect2(Vector2(cells.position) * CELL, Vector2(cells.size) * CELL)
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


const CHUNK := 32  # cells per baked texture side


## Draws every cell once into chunk textures; lights then only touch a few large quads.
func _bake() -> void:
	var art := PixelArt.T
	for cy in ceili(height / float(CHUNK)):
		for cx in ceili(width / float(CHUNK)):
			var img := Image.create_empty(CHUNK * art, CHUNK * art, false, Image.FORMAT_RGBA8)
			for y in range(cy * CHUNK, mini(height, (cy + 1) * CHUNK)):
				for x in range(cx * CHUNK, mini(width, (cx + 1) * CHUNK)):
					var dst := Vector2i(x - cx * CHUNK, y - cy * CHUNK) * art
					img.blit_rect(_tile_for(x, y), Rect2i(0, 0, art, art), dst)
					if rows[y][x] != "#":
						if is_wall(Vector2i(x, y - 1)):
							img.blend_rect(PixelArt.shadow("top"), Rect2i(0, 0, art, art), dst)
						if is_wall(Vector2i(x - 1, y)):
							img.blend_rect(PixelArt.shadow("left"), Rect2i(0, 0, art, art), dst)
			var spr := Sprite2D.new()
			spr.texture = ImageTexture.create_from_image(img)
			spr.centered = false
			spr.scale = Vector2.ONE * (CELL / float(art))
			spr.position = Vector2(cx, cy) * CHUNK * CELL
			add_child(spr)


func _tile_for(x: int, y: int) -> Image:
	var n := int(_noise(x, y) * 255.0)
	match rows[y][x]:
		"#":
			if not is_wall(Vector2i(x, y + 1)):
				return PixelArt.tile("wall_face", n % 2)
			if not is_wall(Vector2i(x, y - 1)):
				return PixelArt.tile("wall_top", 2)
			return PixelArt.tile("wall_top", n % 2)
		".":
			return PixelArt.tile("wood", 2 if n % 11 == 0 else (3 if n % 7 == 0 else n % 2))
		"=":
			return PixelArt.tile("cobble", 1 if n % 5 == 0 else 0)
		"%":
			return PixelArt.tile("rubble", n % 2)
		",":
			return PixelArt.tile("dirt", n % 4)
	return PixelArt.tile("plate", 0)


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




## Furniture inside buildings and junk outside, purely visual (no collision). Seeded so a map
## always looks the same. Skips cells used by spawns, lights and extraction.
func scatter_decor(per_building: int, outdoor: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var taken := {}
	for list in [enemy_spawns, pickup_spawns, container_spawns]:
		for s in list:
			taken[s[0]] = true
	for c in lamp_cells + fire_cells + extract_cells + player_cells:
		taken[c] = true
	for cells in buildings:
		var wall_side: Array = cells.filter(func(c): return not taken.has(c) and _wall_neighbours(c) == 1)
		for i in mini(per_building, wall_side.size()):
			var c: Vector2i = wall_side[rng.randi() % wall_side.size()]
			if _near_taken(taken, c):
				continue
			_decor(["desk", "bed", "bookshelf"][rng.randi() % 3], c, rng)
			taken[c] = true
	var ground := []
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if rows[y][x] in [",", "%", "="] and not taken.has(c) and _wall_neighbours(c) == 0:
				ground.append(c)
	for i in mini(outdoor, ground.size()):
		var c: Vector2i = ground[rng.randi() % ground.size()]
		if _near_taken(taken, c):
			continue
		var kind: String = "car" if rows[c.y][c.x] == "=" else ["rubble", "rubble", "sandbags"][rng.randi() % 3]
		_decor(kind, c, rng)
		taken[c] = true


func _wall_neighbours(c: Vector2i) -> int:
	var n := 0
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_wall(c + d):
			n += 1
	return n


func _near_taken(taken: Dictionary, c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if taken.has(c + Vector2i(dx, dy)):
				return true
	return false


func _decor(kind: String, c: Vector2i, rng: RandomNumberGenerator) -> void:
	var tex := PixelArt.file_texture("prop_" + kind)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * PixelArt.FILE_SCALE
	s.position = cell_to_world(c)
	s.rotation = [0.0, PI * 0.5, PI, PI * 1.5][rng.randi() % 4]
	add_child(s)
