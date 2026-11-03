class_name LightSource
extends Node2D
## A gas lamp that flickers, or a burning barrel / campfire that flares and dims.

var kind := "lamp"  # lamp, fire
var light: PointLight2D
var t := 0.0
var base_energy := 1.0
var off_t := 0.0
var flame: Node2D


func _ready() -> void:
	t = randf() * 10.0
	var spr := Sprite2D.new()
	var prop := "lamp" if kind == "lamp" else "barrel"
	var art := PixelArt.file_texture("prop_" + prop)
	spr.texture = art if art != null else PixelArt.texture("prop:" + prop)
	spr.scale = Vector2.ONE * (PixelArt.FILE_SCALE if art != null else CharacterRig.SCALE)
	add_child(spr)
	if kind == "fire":
		flame = Node2D.new()
		flame.draw.connect(_draw_flame)
		add_child(flame)
	if kind == "lamp":
		base_energy = 1.0
		light = Lights.make(Color(1.0, 0.72, 0.38), 190.0, base_energy, false)
	else:
		base_energy = 1.35
		light = Lights.make(Color(1.0, 0.45, 0.18), 220.0, base_energy, false)
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
		flame.queue_redraw()



func _draw_flame() -> void:
	for i in 5:
		var a := t * 5.0 + i * 1.9
		var p := Vector2(roundf(sin(a) * 3.0) * 2.0, roundf(cos(a * 1.4) * 2.0 - 1.0) * 2.0)
		var s := 6.0 - i
		flame.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(1.0, 0.45 + i * 0.1, 0.12, 0.95))
