class_name CharacterRig
extends Node2D
## A character body rotated as one. Characters with an imported sheet
## (res://assets/sprites/<key>_<pose>.png) swap whole-body poses per weapon class;
## others fall back to a procedural body with a separate held weapon sprite.

const SCALE := 2.0  # art pixel -> world units
const SHEET_DIR := "res://assets/sprites/"
const POSE_OF := {"pistol": "pistol", "silenced": "pistol", "smg": "rifle", "shotgun": "rifle",
	"rifle": "rifle", "bat": "melee", "knife": "melee"}
const BRIGHTNESS := {"pmc": 1.4}  # dark gear needs a lift to read under moonlight

var key := ""
var sheet := false
var body: Sprite2D
var weapon: Sprite2D
var weapon_id := "-"


func _init(body_key: String) -> void:
	key = body_key
	sheet = ResourceLoader.exists(SHEET_DIR + key + "_unarmed.png")
	body = Sprite2D.new()
	body.scale = Vector2.ONE * SCALE
	var b: float = BRIGHTNESS.get(key, 1.0)
	body.self_modulate = Color(b, b, b)
	add_child(body)
	weapon = Sprite2D.new()
	weapon.centered = false
	weapon.scale = Vector2.ONE * SCALE
	weapon.position = Vector2(4, 1)  # grip at the right hand
	weapon.visible = false
	add_child(weapon)
	if not sheet:
		body.texture = PixelArt.texture(key if key in ["toa", "centra"] else "scav:0")
	show_weapon("")


func show_weapon(id: String) -> void:
	if id == weapon_id:
		return
	weapon_id = id
	if sheet:
		body.texture = load(SHEET_DIR + "%s_%s.png" % [key, POSE_OF.get(id, "unarmed")])
		return
	weapon.visible = id != "" and id != "fists"
	if weapon.visible:
		weapon.texture = PixelArt.texture("weapon:" + id)


## facing: body rotation. swing: melee arc, applied to the held weapon or, for sheets, the whole body.
func pose(facing: float, swing: float = 0.0) -> void:
	if sheet:
		rotation = facing + swing * 0.6
	else:
		rotation = facing
		weapon.rotation = swing


func lie_down(angle: float, tint: Color) -> void:
	rotation = angle
	modulate = tint
	show_weapon("")
