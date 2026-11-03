class_name PointerArrow
extends Node2D
## Bobbing yellow arrow over whatever a tutorial wants Toa to walk to.
## With `target` set it follows that node; otherwise it stays where it was put.

var t := 0.0
var target: Node2D = null


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	t += delta
	if target != null and is_instance_valid(target):
		global_position = target.global_position
	queue_redraw()


func _draw() -> void:
	var y := -44.0 + sin(t * 5.0) * 4.0
	var col := Color(1.0, 0.9, 0.3)
	draw_colored_polygon(PackedVector2Array([Vector2(0, y + 10), Vector2(-8, y), Vector2(8, y)]), col)
	draw_rect(Rect2(-3, y - 10, 6, 10), col)
