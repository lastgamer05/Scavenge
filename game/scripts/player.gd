class_name Player
extends CharacterBody2D
## Toa. Two quick slots, no reload: shoot, throw when empty, grab the next gun.

const SPEED := 230.0
const PICKUP_RANGE := 40.0
const EXECUTE_RANGE := 38.0

var game: Node
var alive := true
var slots: Array = [null, null]  # each null or an ItemDB item
var bag := InvGrid.new(6, 4)
var pouch := InvGrid.new(1, 2)  # safe pouch: survives death
var current := 0
var fire_t := 0.0
var swing_t := 0.0
var aim := 0.0
var death_dir := Vector2.RIGHT
var rig: CharacterRig


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	rig = CharacterRig.new("toa")
	add_child(rig)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED * game.speed_mult()
	move_and_slide()
	fire_t -= delta
	swing_t = maxf(0.0, swing_t - delta)
	_update_rig()
	# With the bag open the mouse belongs to the UI; Toa can only walk. No fighting in the hideout.
	if game.inventory.visible:
		return
	aim = (get_global_mouse_position() - global_position).angle()
	if not game.combat:
		return

	var w = slots[current]
	var wd := WeaponDB.get_data(current_id())
	var wants_fire: bool = Input.is_action_just_pressed("fire") or (wd.get("auto", false) and Input.is_action_pressed("fire"))
	if wants_fire and fire_t <= 0.0:
		_attack(w, wd)
	if Input.is_action_just_pressed("throw") and w != null:
		_throw()
	if Input.is_action_just_pressed("swap"):
		current = 1 - current
	if Input.is_action_just_pressed("slot_1"):
		current = 0
	if Input.is_action_just_pressed("slot_2"):
		current = 1


func current_id() -> String:
	var w = slots[current]
	return "fists" if w == null else w["id"]


func aim_dir() -> Vector2:
	return Vector2.from_angle(aim)


func _attack(w, wd: Dictionary) -> void:
	if wd["melee"]:
		fire_t = wd["cooldown"]
		swing_t = 0.15
		_melee(wd)
		return
	if w["ammo"] <= 0:
		fire_t = 0.25
		game.toast("탄 없음 — 우클릭으로 던지기")
		return
	w["ammo"] -= 1
	fire_t = wd["cooldown"]
	var muzzle: Vector2 = global_position + aim_dir() * (10.0 + wd["length"])
	for i in wd["pellets"]:
		var a := aim + deg_to_rad(randf_range(-wd["spread"], wd["spread"]))
		game.spawn_bullet(muzzle, a, true, get_rid())
	game.spawn_fx("flash", muzzle)
	game.make_noise(global_position, wd["noise"], self)
	game.add_shake(3.0 if wd["pellets"] == 1 else 7.0)


func _melee(wd: Dictionary) -> void:
	var reach: float = wd["range"] + 10.0
	var half_arc := deg_to_rad(wd["arc"] * 0.5 + 10.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_dead():
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > reach or absf(angle_difference(aim, to.angle())) > half_arc:
			continue
		if not game.has_los(global_position, e.global_position):
			continue
		if wd["lethal"] or e.is_down():
			e.kill(to.normalized())
		else:
			e.stun(to.normalized(), 2.2)
		game.add_shake(4.0)
	game.make_noise(global_position, wd["noise"], self)


func _throw() -> void:
	var w = slots[current]
	slots[current] = null
	game.spawn_pickup(w["id"], w["ammo"], global_position + aim_dir() * 14.0, aim_dir() * 720.0, true)


## E: execute a downed enemy, pick up a weapon or search a container, whichever is closest.
func interact() -> void:
	var target: Dictionary = game.interact_target(global_position)
	match target.get("type", ""):
		"execute":
			var downed = target["node"]
			downed.kill((downed.global_position - global_position).normalized())
			swing_t = 0.2
			game.make_noise(global_position, 60.0, self)
		"pickup":
			_pick_up(target["node"])
		"search":
			game.inventory.open(target["node"])
		"flare":
			target["node"].fire_flare(game)
		"npc", "exit":
			target["node"].interact()


func _pick_up(p: WeaponPickup) -> void:
	var item := ItemDB.make(p.weapon_id, p.ammo)
	if slots[current] == null:
		slots[current] = item
	elif slots[1 - current] == null:
		current = 1 - current
		slots[current] = item
	else:
		var old = slots[current]
		game.spawn_pickup(old["id"], old["ammo"], global_position, Vector2.ZERO, false)
		slots[current] = item
	p.queue_free()


func take_hit(dir: Vector2, _from_player: bool) -> void:
	if not alive:
		return
	alive = false
	death_dir = dir
	collision_layer = 0
	rig.lie_down(dir.angle(), Color(0.65, 0.5, 0.5))
	rig.position = dir * 6.0
	game.on_player_died(dir)


func _update_rig() -> void:
	var id := current_id()
	var swing := 0.0
	if WeaponDB.get_data(id)["melee"] and swing_t > 0.0:
		swing = -1.2 + (0.15 - swing_t) / 0.15 * 2.4
	rig.show_weapon(id)
	rig.pose(aim, swing)
