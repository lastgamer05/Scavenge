class_name FX
extends Node2D
## Short-lived visual effect: noise ring, wall spark, muzzle flash, alert mark.

var kind := "spark"
var radius := 0.0
var life := 0.25
var t := 0.0


func _ready() -> void:
	if kind == "flash":
		add_child(Lights.make(Color(1.0, 0.8, 0.45), 150.0, 1.4, false))
	elif kind == "boom":
		add_child(Lights.make(Color(1.0, 0.55, 0.25), 340.0, 2.4, false))


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / life
	match kind:
		"noise":
			draw_arc(Vector2.ZERO, radius * (0.2 + 0.8 * k), 0.0, TAU, 64, Color(1, 1, 1, 0.22 * (1.0 - k)), 2.0)
		"spark":
			for i in 5:
				var d := Vector2.from_angle(i * 1.3 + radius)
				draw_line(d * 2.0, d * (4.0 + 8.0 * k), Color(1, 0.85, 0.5, 1.0 - k), 1.5)
		"flash":
			draw_circle(Vector2.ZERO, 9.0 * (1.0 - k), Color(1, 0.85, 0.4, 1.0 - k))
		"boom":
			# Fireball, shock ring and flying debris; radius is the blast size.
			var r := radius * (0.3 + 0.7 * sqrt(k))
			draw_circle(Vector2.ZERO, r * 0.7, Color(1.0, 0.6 + 0.3 * (1.0 - k), 0.2, 1.0 - k))
			draw_circle(Vector2.ZERO, r * 0.4, Color(1.0, 0.95, 0.7, maxf(0.0, 1.0 - k * 2.0)))
			draw_arc(Vector2.ZERO, r * 1.3, 0.0, TAU, 40, Color(1, 1, 1, 0.5 * (1.0 - k)), 3.0)
			for i in 10:
				var d := Vector2.from_angle(i * 0.63 + radius)
				draw_rect(Rect2(d * r * (1.0 + k), Vector2(4, 4)), Color(0.25, 0.2, 0.18, 1.0 - k))
