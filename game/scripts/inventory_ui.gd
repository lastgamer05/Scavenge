class_name InventoryUI
extends Control
## Bag screen: quick slots, bag, safe pouch and whatever Toa is looking into (crate, stash, trader).
## In a raid time slows to 30% while open; the world keeps moving and Toa can still walk.
## Drag to move, R or right-click to rotate, Shift+click to quick-move, drag outside to drop.
## Every move between places asks game.transfer(), which lets the hideout charge, pay or refuse.

const CELL := 44
const SLOW := 0.3
const SLOT_SIZE := Vector2(CELL * 3, CELL * 2)
const PANEL_GAP := 60.0
const POUCH_GAP := 44.0
const LEAVE_RANGE := 72.0

var game: Node
var other: LootContainer = null
var drag = null  # item dictionary being dragged
var drag_src = null  # InvGrid, or int quick slot index
var drag_origin := Vector2i.ZERO
var drag_origin_rot := false
var drag_grab := Vector2.ZERO
var bag_origin := Vector2.ZERO
var pouch_origin := Vector2.ZERO
var other_origin := Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open(container: LootContainer) -> void:
	other = container
	visible = true
	Engine.time_scale = SLOW if game.combat else 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout()
	queue_redraw()


func close() -> void:
	if not visible:
		return
	if drag != null:
		_return_drag()
	visible = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_detach_other()


func _detach_other() -> void:
	if other != null and is_instance_valid(other):
		other.on_closed()
	other = null


func _bag() -> InvGrid:
	return game.player.bag


func _pouch() -> InvGrid:
	return game.player.pouch


func _slots() -> Array:
	return game.player.slots


func _process(_delta: float) -> void:
	if not visible:
		return
	if other != null and (not is_instance_valid(other)
			or other.global_position.distance_to(game.player.global_position) > LEAVE_RANGE):
		_detach_other()
	_layout()
	queue_redraw()


func _layout() -> void:
	var bag := _bag()
	var bag_px := Vector2(bag.w, bag.h) * CELL
	var total_w := bag_px.x
	if other != null:
		total_w += PANEL_GAP + other.grid.w * CELL
	var total_h := bag_px.y + POUCH_GAP + _pouch().h * CELL
	bag_origin = Vector2(floorf((size.x - total_w) * 0.5), floorf(size.y * 0.5 - total_h * 0.5 + 40.0))
	pouch_origin = bag_origin + Vector2(0, bag_px.y + POUCH_GAP)
	other_origin = bag_origin + Vector2(bag_px.x + PANEL_GAP, 0)


func _slot_rect(i: int) -> Rect2:
	return Rect2(bag_origin + Vector2(i * (SLOT_SIZE.x + 12.0), -SLOT_SIZE.y - 44.0), SLOT_SIZE)


func _grid_rect(origin: Vector2, grid: InvGrid) -> Rect2:
	return Rect2(origin, Vector2(grid.w, grid.h) * CELL)


func _grids() -> Array:
	var list := [{"grid": _bag(), "origin": bag_origin}, {"grid": _pouch(), "origin": pouch_origin}]
	if other != null:
		list.append({"grid": other.grid, "origin": other_origin})
	return list


## What is under a screen position: {"slot": i}, {"grid": InvGrid, "origin": Vector2} or {}.
func _target_at(pos: Vector2) -> Dictionary:
	for i in 2:
		if _slot_rect(i).has_point(pos):
			return {"slot": i}
	for g in _grids():
		if _grid_rect(g["origin"], g["grid"]).has_point(pos):
			return g
	return {}


func _over_panel(pos: Vector2) -> bool:
	var area := _slot_rect(0).merge(_slot_rect(1))
	for g in _grids():
		area = area.merge(_grid_rect(g["origin"], g["grid"]))
	return area.grow(30.0).has_point(pos)


func _cell_at(origin: Vector2, pos: Vector2) -> Vector2i:
	return Vector2i(((pos - origin) / CELL).floor())


func _other_grid(grid: InvGrid) -> InvGrid:
	if grid == _bag():
		return other.grid if other != null else null
	return _bag()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press(mb.position, mb.shift_pressed)
		elif drag != null:
			_release(mb.position)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		rotate_drag()
		accept_event()


func _press(pos: Vector2, shift: bool) -> void:
	var t := _target_at(pos)
	if t.has("slot"):
		var item = _slots()[t["slot"]]
		if item == null:
			return
		_slots()[t["slot"]] = null
		if shift:
			if not _bag().auto_add(item):
				_slots()[t["slot"]] = item
			return
		_begin_drag(item, t["slot"], pos, Vector2(CELL, CELL) * 0.5)
		return
	if not t.has("grid"):
		return
	var grid: InvGrid = t["grid"]
	var item = grid.item_at(_cell_at(t["origin"], pos))
	if item == null:
		return
	if shift:
		_quick_move(item, grid)
		return
	grid.remove(item)
	var item_px: Vector2 = t["origin"] + Vector2(item["x"], item["y"]) * CELL
	_begin_drag(item, grid, pos, pos - item_px)


func _quick_move(item: Dictionary, grid: InvGrid) -> void:
	var dest := _other_grid(grid)
	if dest == null:
		# Bag only: Shift+click a weapon to equip it into an empty quick slot.
		var free := _slots().find(null)
		if ItemDB.is_weapon(item["id"]) and free >= 0 and game.transfer(item, grid, free) == "ok":
			grid.remove(item)
			_slots()[free] = item
		return
	var from := Vector3i(item["x"], item["y"], int(item["rot"]))
	grid.remove(item)
	if not dest.auto_add(item):
		grid.add_at(item, from.x, from.y, from.z == 1)
		return
	match game.transfer(item, grid, dest):
		"deny":
			dest.remove(item)
			grid.add_at(item, from.x, from.y, from.z == 1)
		"consumed":
			dest.remove(item)


func _begin_drag(item: Dictionary, src, pos: Vector2, grab: Vector2) -> void:
	drag = item
	drag_src = src
	drag_origin = Vector2i(item["x"], item["y"])
	drag_origin_rot = item["rot"]
	drag_grab = grab


func _drop_cell(t: Dictionary, pos: Vector2) -> Vector2i:
	return _cell_at(t["origin"], pos - drag_grab + Vector2(CELL, CELL) * 0.5)


func _release(pos: Vector2) -> void:
	var item: Dictionary = drag
	var t := _target_at(pos)
	if t.has("slot"):
		if ItemDB.is_weapon(item["id"]) and game.transfer(item, drag_src, t["slot"]) == "ok":
			var prev = _slots()[t["slot"]]
			_slots()[t["slot"]] = item
			drag = null
			if prev != null:
				_stash(prev)
			return
	elif t.has("grid"):
		var c := _drop_cell(t, pos)
		var g: InvGrid = t["grid"]
		if g.fits(item, c.x, c.y, item["rot"]):
			match game.transfer(item, drag_src, g):
				"ok":
					g.add_at(item, c.x, c.y, item["rot"])
					drag = null
					return
				"consumed":
					drag = null
					return
	elif not _over_panel(pos) and game.transfer(item, drag_src, "drop") == "ok":
		game.drop_item(item)
		drag = null
		return
	_return_drag()


## Puts an item displaced from a quick slot back where the dragged item came from.
func _stash(item: Dictionary) -> void:
	if drag_src is int:
		_slots()[drag_src] = item
	elif drag_src is InvGrid and drag_src.add_at(item, drag_origin.x, drag_origin.y, item["rot"]):
		pass
	elif not _bag().auto_add(item):
		game.drop_item(item)


func _return_drag() -> void:
	var item: Dictionary = drag
	drag = null
	if drag_src is int:
		_slots()[drag_src] = item
	elif not drag_src.add_at(item, drag_origin.x, drag_origin.y, drag_origin_rot):
		if not _bag().auto_add(item):
			game.drop_item(item)


func rotate_drag() -> void:
	if drag == null:
		return
	drag["rot"] = not drag["rot"]
	drag_grab = Vector2(CELL, CELL) * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var font := get_theme_default_font()
	var bag := _bag()
	_draw_title(font, bag_origin, bag.w * CELL, "가방", "%.1fkg   $%d" % [game.carried_weight(), bag.total_value()])
	_draw_grid(font, bag_origin, bag)
	_draw_title(font, pouch_origin, maxf(_pouch().w * CELL, 280.0), "안전 파우치", "죽어도 남는다")
	_draw_grid(font, pouch_origin, _pouch())
	for i in 2:
		var r := _slot_rect(i)
		draw_rect(r, Color(0.1, 0.1, 0.12, 0.95))
		draw_rect(r, Color(0.45, 0.45, 0.5), false, 1.5)
		draw_string(font, r.position + Vector2(0, -6), "퀵슬롯 %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
		var it = _slots()[i]
		if it != null:
			_draw_item(font, r.grow(-6.0), it, 1.0)
	if other != null:
		var sub := "비어 있음" if other.grid.items.is_empty() else "$%d" % other.grid.total_value()
		_draw_title(font, other_origin, other.grid.w * CELL, other.title, sub)
		_draw_grid(font, other_origin, other.grid)

	var m := get_local_mouse_position()
	var t := _target_at(m)
	if drag != null:
		var s := ItemDB.size_of(drag, drag["rot"])
		if t.has("grid"):
			var c := _drop_cell(t, m)
			var ok: bool = t["grid"].fits(drag, c.x, c.y, drag["rot"])
			var col := Color(0.3, 1.0, 0.4, 0.3) if ok else Color(1.0, 0.3, 0.3, 0.3)
			draw_rect(Rect2(t["origin"] + Vector2(c) * CELL, Vector2(s) * CELL), col)
		elif not _over_panel(m):
			draw_string(font, m + Vector2(14, 30), "버리기", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.6, 0.5))
		_draw_item(font, Rect2(m - drag_grab, Vector2(s) * CELL).grow(-2.0), drag, 0.85)

	var hovered = drag
	var hovered_grid = drag_src if drag != null else null
	if hovered == null:
		if t.has("slot"):
			hovered = _slots()[t["slot"]]
		elif t.has("grid"):
			hovered = t["grid"].item_at(_cell_at(t["origin"], m))
			hovered_grid = t["grid"]
	var bottom := maxf(pouch_origin.y + _pouch().h * CELL, other_origin.y + (other.grid.h * CELL if other != null else 0.0))
	if hovered != null:
		var d := ItemDB.get_data(hovered["id"])
		var info := "%s    $%d    %.1fkg" % [d["name"], d["value"], d["weight"]]
		if WeaponDB.is_gun(hovered["id"]):
			info += "    탄 %d/%d" % [hovered["ammo"], WeaponDB.get_data(hovered["id"])["ammo"]]
		var hint: String = game.price_hint(hovered, hovered_grid)
		if hint != "":
			info += "    " + hint
		draw_string(font, Vector2(0, bottom + 40), info, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 0.95, 0.8))
	draw_string(font, Vector2(0, bottom + 76),
		"드래그 이동   R/우클릭 회전   Shift+클릭 빠른 이동   밖으로 끌어 버리기   Tab/E 닫기",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(1, 1, 1, 0.6))


## Fits an icon into a rect at an integer scale, turning wide icons upright for tall slots.
func _draw_icon(icon: Texture2D, r: Rect2, alpha: float) -> void:
	var s := Vector2(icon.get_size())
	var upright := r.size.y > r.size.x * 1.3 and s.x > s.y
	var fit := r.size if not upright else Vector2(r.size.y, r.size.x)
	var k := maxf(1.0, floorf(minf(fit.x / s.x, fit.y / s.y)))
	if s.x * k > fit.x or s.y * k > fit.y:
		k = minf(fit.x / s.x, fit.y / s.y)
	var size := s * k
	draw_set_transform(r.get_center(), PI * 0.5 if upright else 0.0)
	draw_texture_rect(icon, Rect2(-size * 0.5, size), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_title(font: Font, origin: Vector2, width: float, title: String, sub: String) -> void:
	draw_string(font, origin + Vector2(0, -12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, origin + Vector2(0, -12), sub, HORIZONTAL_ALIGNMENT_RIGHT, width, 11, Color(0.8, 0.8, 0.8))


func _draw_grid(font: Font, origin: Vector2, grid: InvGrid) -> void:
	for y in grid.h:
		for x in grid.w:
			var r := Rect2(origin + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			draw_rect(r, Color(0.13, 0.13, 0.15, 0.95))
			draw_rect(r, Color(0.26, 0.26, 0.3), false, 1.0)
	for item in grid.items:
		var rect := grid.rect_of(item)
		_draw_item(font, Rect2(origin + Vector2(rect.position) * CELL, Vector2(rect.size) * CELL).grow(-2.0), item, 1.0)


func _draw_item(font: Font, r: Rect2, item: Dictionary, alpha: float) -> void:
	var d := ItemDB.get_data(item["id"])
	var col: Color = d["color"]
	draw_rect(r, Color(col.darkened(0.55), alpha * 0.9))
	draw_rect(r, Color(col.lightened(0.2), alpha), false, 1.5)
	var icon := PixelArt.file_texture("item_" + item["id"])
	if icon == null:
		draw_multiline_string(font, r.position + Vector2(4, 14), d["name"], HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 6.0, 11, 3, Color(1, 1, 1, alpha))
	else:
		_draw_icon(icon, r.grow(-4.0), alpha)
	if WeaponDB.is_gun(item["id"]):
		draw_string(font, r.position + Vector2(0, r.size.y - 5), str(item["ammo"]), HORIZONTAL_ALIGNMENT_RIGHT,
			r.size.x - 4.0, 11, Color(1, 0.9, 0.5, alpha))
