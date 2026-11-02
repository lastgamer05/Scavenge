class_name CharacterRig
extends Node2D
## Pixel sprite body plus a held weapon, rotated as one. Used by Toa and every enemy.

const SCALE := 2.0  # art pixel -> world units

var body: Sprite2D
var weapon: Sprite2D
var weapon_id := ""


func _init(body_key: String) -> void:
	body = Sprite2D.new()
	body.texture = PixelArt.texture(body_key)
	body.scale = Vector2.ONE * SCALE
	add_child(body)
	weapon = Sprite2D.new()
	weapon.centered = false
	weapon.scale = Vector2.ONE * SCALE
	weapon.position = Vector2(4, 1)  # grip at the right hand
	weapon.visible = false
	add_child(weapon)


func show_weapon(id: String) -> void:
	if id == weapon_id:
		return
	weapon_id = id
	weapon.visible = id != "" and id != "fists"
	if weapon.visible:
		weapon.texture = PixelArt.texture("weapon:" + id)


## facing: body rotation. swing: extra weapon rotation for melee arcs.
func pose(facing: float, swing: float = 0.0) -> void:
	rotation = facing
	weapon.rotation = swing


func lie_down(angle: float, tint: Color) -> void:
	rotation = angle
	modulate = tint
	show_weapon("")
