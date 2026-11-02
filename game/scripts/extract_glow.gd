extends Node2D
## Pulsing marker over extraction cells.

var cells: Array[Vector2i] = []
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if cells.is_empty():
		return
	var a := 0.25 + 0.15 * sin(t * 4.0)
	var top_left := Vector2(cells[0]) * Level.CELL
	for c in cells:
		var p := Vector2(c) * Level.CELL
		draw_rect(Rect2(p, Vector2(Level.CELL, Level.CELL)), Color(0.2, 1.0, 0.45, a))
		top_left = top_left.min(p)
	draw_string(ThemeDB.fallback_font, top_left + Vector2(2, -6), "EXTRACT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 1.0, 0.6))
