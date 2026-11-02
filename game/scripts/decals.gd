class_name Decals
extends Node2D
## Persistent blood splats under everything else.

var splats: Array = []  # [Vector2, radius]


func add_blood(pos: Vector2, dir: Vector2) -> void:
	for i in 8:
		var p := pos + dir * randf_range(0.0, 34.0) + Vector2(randf_range(-9, 9), randf_range(-9, 9))
		splats.append([p, randf_range(3.0, 10.0)])
	queue_redraw()


func _draw() -> void:
	for s in splats:
		draw_circle(s[0], s[1], Color(0.42, 0.03, 0.05, 0.9))
