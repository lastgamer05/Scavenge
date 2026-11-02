class_name Door
extends StaticBody2D
## A locked steel door over a row of map cells. Opening it removes the collision.

var cells: Array = []  # Vector2i cells it blocks
var open := false
var sprite_rect := Rect2()


func setup(level: Level, door_cells: Array) -> void:
	cells = door_cells
	collision_layer = 1
	collision_mask = 0
	var lo := Vector2(door_cells[0]) * Level.CELL
	var hi := lo
	for c in door_cells:
		lo = lo.min(Vector2(c) * Level.CELL)
		hi = hi.max(Vector2(c) * Level.CELL + Vector2(Level.CELL, Level.CELL))
	sprite_rect = Rect2(lo, hi - lo)
	var shape := RectangleShape2D.new()
	shape.size = sprite_rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = sprite_rect.get_center()
	add_child(cs)
	var occ := LightOccluder2D.new()
	occ.occluder = OccluderPolygon2D.new()
	occ.occluder.polygon = PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])
	add_child(occ)
	for c in door_cells:
		level.astar.set_point_solid(c, true)


func center() -> Vector2:
	return sprite_rect.get_center()


func unlock(level: Level) -> void:
	open = true
	for c in cells:
		level.astar.set_point_solid(c, false)
	for child in get_children():
		child.queue_free()
	queue_redraw()


func _draw() -> void:
	if open:
		draw_rect(sprite_rect.grow_individual(0, -12, 0, -12), Color(0.2, 0.2, 0.22))
		return
	draw_rect(sprite_rect, Color(0.36, 0.38, 0.42))
	draw_rect(sprite_rect.grow(-3), Color(0.28, 0.3, 0.34))
	draw_rect(Rect2(sprite_rect.get_center() - Vector2(5, 5), Vector2(10, 10)), Color(0.8, 0.25, 0.2))
