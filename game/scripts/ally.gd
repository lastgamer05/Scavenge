class_name Ally
extends CharacterBody2D
## A contractor teammate in the prologue: follows Toa and shoots enemies it can see.
## Enemies ignore allies, and allies cannot die until the script says so.

const SPEED := 200.0
const SIGHT := 380.0

var game: Node
var follow_offset := Vector2.ZERO
var display_name := ""
var rig: CharacterRig
var facing := 0.0
var fire_t := 0.0
var down := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	rig = CharacterRig.new("pmc")
	rig.show_weapon("rifle")
	add_child(rig)
	var label := Label.new()
	label.text = display_name
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	label.position = Vector2(-40, -34)
	label.size = Vector2(80, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


func _physics_process(delta: float) -> void:
	if down:
		return
	fire_t -= delta
	var target := _visible_enemy()
	var goal: Vector2 = game.player.global_position + follow_offset.rotated(game.player.aim)
	var to_goal := goal - global_position
	velocity = to_goal.normalized() * SPEED if to_goal.length() > 18.0 else Vector2.ZERO
	move_and_slide()
	var look := (target.global_position - global_position).angle() if target != null else velocity.angle() if velocity.length() > 1.0 else facing
	facing = rotate_toward(facing, look, delta * 10.0)
	rig.pose(facing)
	if target != null and fire_t <= 0.0:
		fire_t = randf_range(0.45, 0.8)
		var a := (target.global_position - global_position).angle() + deg_to_rad(randf_range(-5.0, 5.0))
		game.spawn_bullet(global_position + Vector2.from_angle(a) * 22.0, a, true, get_rid())
		game.spawn_fx("flash", global_position + Vector2.from_angle(a) * 22.0)


func _visible_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := SIGHT
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_dead():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d and game.has_los(global_position, e.global_position):
			best = e
			best_d = d
	return best


## The bombing: the teammate falls.
func die(dir: Vector2) -> void:
	down = true
	rig.lie_down(dir.angle(), Color(0.55, 0.42, 0.42))
	game.decals.add_blood(global_position, dir)
