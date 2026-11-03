class_name CharacterRig
extends Node2D
## A character body rotated as one. Characters with imported sheets
## (res://assets/sprites/<key>_<frame>.png) pick a whole-body frame each tick:
##   unarmed: idle (arms at the sides) or a two-frame walk cycle
##   guns: rifle / pistol pose
##   bat: wind-up while ready, then mid-swing and follow-through when swinging
##   knife: knife pose, lunging forward on a stab
##   down: lying flat, for the stunned and the dead
## Characters without sheets fall back to a procedural body with a separate weapon sprite.

const SCALE := 2.0  # art pixel -> world units
const SHEET_DIR := "res://assets/sprites/"
const GUN_POSE := {"pistol": "pistol", "silenced": "pistol", "smg": "rifle", "shotgun": "rifle", "rifle": "rifle"}
const STEP_TIME := 0.16  # seconds per walk frame
const BRIGHTNESS := {}  # per-sheet brightness lift; the regenerated sheets read fine as they are

var key := ""
var sheet := false
var animated := false  # has idle/walk/melee frames, not just the four static poses
var body: Sprite2D
var weapon: Sprite2D
var weapon_id := "-"
var frame := ""
var walk_t := 0.0
var lying := false


func _init(body_key: String) -> void:
	key = body_key
	animated = ResourceLoader.exists(SHEET_DIR + key + "_idle.png")
	sheet = animated or ResourceLoader.exists(SHEET_DIR + key + "_unarmed.png")
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


## Shows a named frame directly (NPC moods); ignored for characters without sheets.
func set_frame(name: String) -> void:
	if animated and not lying:
		_set_frame(name)


func _set_frame(name: String) -> void:
	if name == frame:
		return
	frame = name
	body.texture = load(SHEET_DIR + "%s_%s.png" % [key, name])


func show_weapon(id: String) -> void:
	if id == weapon_id:
		return
	weapon_id = id
	if sheet:
		_set_frame(GUN_POSE.get(id, "idle" if animated else ("melee" if id in ["bat", "knife"] else "unarmed")))
		return
	weapon.visible = id != "" and id != "fists"
	if weapon.visible:
		weapon.texture = PixelArt.texture("weapon:" + id)


## Picks this tick's frame. swing: -1 when not attacking, else 0..1 through the attack.
func animate(delta: float, id: String, moving: bool, swing: float) -> void:
	if lying:
		return
	show_weapon(id)
	if not animated:
		return
	body.position = Vector2.ZERO
	if GUN_POSE.has(id):
		_set_frame(GUN_POSE[id])
	elif id == "bat":
		if swing < 0.0:
			_set_frame("bat_windup")
		else:
			_set_frame("bat_mid" if swing < 0.45 else "bat_follow")
	elif id == "knife":
		_set_frame("knife")
		if swing >= 0.0:
			body.position = Vector2(sin(swing * PI) * 5.0, 0)
	else:
		if moving:
			walk_t += delta
			_set_frame("walk1" if int(walk_t / STEP_TIME) % 2 == 0 else "walk2")
		else:
			walk_t = 0.0
			_set_frame("idle")
		if swing >= 0.0:
			body.position = Vector2(sin(swing * PI) * 4.0, 0)  # a punch: lean in


## facing: body rotation. swing: melee arc for characters without swing frames.
func pose(facing: float, swing: float = 0.0) -> void:
	if lying:
		return
	if animated:
		rotation = facing
	elif sheet:
		rotation = facing + swing * 0.6
	else:
		rotation = facing
		weapon.rotation = swing


func lie_down(angle: float, tint: Color) -> void:
	lying = true
	rotation = angle
	modulate = tint
	body.position = Vector2.ZERO
	weapon.visible = false
	if animated:
		_set_frame("down")


func get_up() -> void:
	lying = false
	modulate = Color.WHITE
