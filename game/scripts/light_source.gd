class_name LightSource
extends Node2D
## A gas lamp that flickers, or a burning barrel / campfire that flares and dims.

var kind := "lamp"  # lamp, fire
var light: PointLight2D
var t := 0.0
var base_energy := 1.0
var off_t := 0.0


func _ready() -> void:
	t = randf() * 10.0
	if kind == "lamp":
		base_energy = 1.0
		light = Lights.make(Color(1.0, 0.72, 0.38), 190.0, base_energy, true)
	else:
		base_energy = 1.35
		light = Lights.make(Color(1.0, 0.45, 0.18), 220.0, base_energy, true)
	add_child(light)


func _process(delta: float) -> void:
	t += delta
	if kind == "lamp":
		# Mostly steady, with short dropouts like a failing gas mantle.
		off_t -= delta
		if off_t <= 0.0 and randf() < delta * 0.35:
			off_t = randf_range(0.05, 0.35)
		light.energy = 0.08 if off_t > 0.0 else base_energy + sin(t * 23.0) * 0.04
	else:
		light.energy = base_energy + sin(t * 9.0) * 0.12 + sin(t * 23.0 + 1.3) * 0.08
		light.texture_scale = (220.0 + sin(t * 6.0) * 8.0) * 2.0 / Lights.TEX_SIZE
		queue_redraw()


func _draw() -> void:
	if kind == "lamp":
		draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.2, 0.22))
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.85, 0.55, 0.4 if off_t > 0.0 else 1.0))
		return
	draw_circle(Vector2.ZERO, 10.0, Color(0.25, 0.2, 0.18))
	draw_circle(Vector2.ZERO, 8.0, Color(0.12, 0.08, 0.06))
	for i in 4:
		var a := t * 3.0 + i * 1.7
		var p := Vector2(sin(a) * 3.0, cos(a * 1.3) * 3.0 - 1.0)
		draw_circle(p, 4.0 - i * 0.6, Color(1.0, 0.55 + i * 0.1, 0.15, 0.9))
