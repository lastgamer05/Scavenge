class_name Npc
extends Node2D
## A Bapas member in the hideout. Talking opens their dialogue; traders also open their counter.

const NAMES := {"leader": "리더 하엘", "weapons": "무기상 고르", "doctor": "의사 미라",
	"junk": "고물상 텁", "informant": "정보원 쥐"}

var role := "junk"
var hideout: Node
var counter: LootContainer = null  # trade grid shown next to Toa's bag
var rig: CharacterRig
var mood := "idle"  # idle, work, alt: what the NPC does while nobody talks to them
var mood_t := 0.0
var talk_t := 0.0


func _ready() -> void:
	add_to_group("npcs")
	var sheet_key := "npc_" + role
	rig = CharacterRig.new(sheet_key if ResourceLoader.exists("res://assets/sprites/%s_idle.png" % sheet_key) else "npc:" + role)
	mood_t = randf_range(1.0, 4.0)
	rig.rotation = PI * 0.5  # face down into the station until Toa comes close
	add_child(rig)
	var label := Label.new()
	label.text = NAMES[role]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.position = Vector2(-40, -34)
	label.size = Vector2(80, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.light_mask = 0
	add_child(label)


func title() -> String:
	return NAMES[role]


func interact() -> void:
	hideout.talk_to(self)


func _process(delta: float) -> void:
	# Turn to face Toa when close.
	var p: Node2D = hideout.player
	if p.global_position.distance_to(global_position) < 160.0:
		rig.rotation = rotate_toward(rig.rotation, (p.global_position - global_position).angle(), 0.08)
	var talking: bool = hideout.dialog_npc == self or (counter != null and hideout.inventory.visible
		and hideout.inventory.other == counter)
	if talking:
		# Gesture on and off while the conversation or trade is open.
		talk_t += delta
		rig.set_frame("talk" if int(talk_t / 0.6) % 2 == 0 else "idle")
		return
	talk_t = 0.0
	mood_t -= delta
	if mood_t <= 0.0:
		var roll := randf()
		mood = "work" if roll < 0.35 else ("alt" if roll < 0.55 else "idle")
		mood_t = randf_range(2.0, 5.0)
	rig.set_frame(mood)
