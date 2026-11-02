class_name Lights
extends RefCounted
## Shared light texture and factory. Moonlight is a CanvasModulate; everything warm is a PointLight2D.

const MOONLIGHT := Color(0.42, 0.47, 0.64)
const TEX_SIZE := 256

static var _texture: GradientTexture2D


static func texture() -> GradientTexture2D:
	if _texture == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.add_point(0.45, Color(1, 1, 1, 0.55))
		_texture = GradientTexture2D.new()
		_texture.gradient = grad
		_texture.width = TEX_SIZE
		_texture.height = TEX_SIZE
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
	return _texture


static func make(color: Color, radius: float, energy: float, shadows: bool) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = texture()
	l.texture_scale = radius * 2.0 / TEX_SIZE
	l.color = color
	l.energy = energy
	l.range_item_cull_mask = 1
	l.shadow_enabled = shadows
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_item_cull_mask = 1
	return l
