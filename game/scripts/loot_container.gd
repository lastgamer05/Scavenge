class_name LootContainer
extends Node2D
## Something to search: crate, locker, safe, corpse or a pile of dropped items.

var kind := "crate"
var title := ""
var grid: InvGrid
var searched := false


func setup(container_kind: String, fill_loot: bool = true) -> void:
	kind = container_kind
	var table: Dictionary = ItemDB.LOOT[kind]
	title = table["title"]
	var s: Vector2i = table["size"]
	grid = InvGrid.new(s.x, s.y)
	if fill_loot:
		ItemDB.fill(grid, kind)


func _ready() -> void:
	add_to_group("containers")


## Called when the inventory screen closes on this container.
func on_closed() -> void:
	searched = true
	if kind == "pile" and grid.items.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	var empty_tint := 0.55 if searched and grid.items.is_empty() else 1.0
	match kind:
		"crate":
			draw_rect(Rect2(-12, -12, 24, 24), Color(0.45, 0.32, 0.18) * empty_tint)
			draw_rect(Rect2(-12, -12, 24, 24), Color(0.25, 0.17, 0.1), false, 2.0)
			draw_line(Vector2(-12, -12), Vector2(12, 12), Color(0.3, 0.2, 0.12), 2.0)
		"locker":
			draw_rect(Rect2(-10, -14, 20, 28), Color(0.35, 0.4, 0.45) * empty_tint)
			draw_line(Vector2(0, -14), Vector2(0, 14), Color(0.2, 0.22, 0.25), 1.5)
		"safe":
			draw_rect(Rect2(-12, -12, 24, 24), Color(0.25, 0.27, 0.3) * empty_tint)
			draw_circle(Vector2.ZERO, 5.0, Color(0.7, 0.6, 0.3) * empty_tint)
		"pile":
			draw_circle(Vector2.ZERO, 8.0, Color(0.5, 0.45, 0.35))
			draw_circle(Vector2(5, 3), 5.0, Color(0.4, 0.35, 0.28))
	if not searched and kind != "corpse" and kind != "pile":
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(1, 1, 1, 0.18), 1.5)
