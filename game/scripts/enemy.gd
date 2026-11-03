class_name Enemy
extends CharacterBody2D
## Patrols, investigates noise, chases and shoots on sight. Scavengers drop to one bullet,
## contractors to two; blades, bats and executions drop anyone but a boss.
## On spotting Toa they shoulder the gun first (a visible aim line), then start loose and tighten.

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, STUNNED, DEAD }

const SIGHT_RANGE := 440.0
const HALF_FOV := 1.13  # ~65 degrees
const CLOSE_SENSE := 48.0
const REACTION := 0.8
const TURN_RATE := 5.0  # radians per second while tracking Toa
const AIM_SETTLE := 1.5  # seconds of sight until shots reach the weapon's own spread
const AIM_LOOSE := 10.0  # extra spread in degrees on the first shot
const SHOOT_RANGE := 340.0
const LABEL_FONT := preload("res://assets/fonts/Galmuri11-Bold.ttf")

var game: Node
var level: Level
var weapon_id := "pistol"
var state := State.PATROL
var facing := 0.0
var alerted := false
var path := PackedVector2Array()
var path_i := 0
var repath_t := 0.0
var last_known := Vector2.ZERO
var react_t := 0.0
var fire_t := 0.0
var stun_t := 0.0
var search_t := 0.0
var idle_t := 0.0
var swing_t := -1.0
var aim_t := 0.0
var strike_t := 0.0  # after the hit lands: drives the swing / follow-through frames
var home := Vector2.ZERO
var death_dir := Vector2.RIGHT
var hp := 1
var boss_name := ""
var centra := false  # Centra soldier instead of a scavenger
var skill := 1.0  # zone difficulty: divides reaction and aim-settle times
var passive := false  # combat-lesson target: stands still and never fights back
var rig: CharacterRig
var mark_node: Node2D
var mark := ""


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	add_to_group("enemies")
	var look := "centra"
	if not centra:
		# Contractors carry the heavier guns; scavengers make do with the rest.
		look = "pmc" if weapon_id in ["smg", "rifle", "shotgun"] and randf() < 0.6 else "scav"
	if look == "pmc" and hp == 1:
		hp = 2
	rig = CharacterRig.new(look)
	add_child(rig)
	mark_node = Node2D.new()
	mark_node.draw.connect(_draw_mark)
	add_child(mark_node)
	home = global_position
	facing = randf() * TAU
	idle_t = randf_range(1.0, 3.0)


func is_dead() -> bool:
	return state == State.DEAD


func is_down() -> bool:
	return state == State.STUNNED


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if state == State.PATROL and global_position.distance_squared_to(game.player.global_position) > 1300.0 * 1300.0:
		return
	fire_t -= delta
	if state == State.STUNNED:
		stun_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
		if stun_t <= 0.0:
			_recover()
		_update_visuals(delta)
		return

	if passive:
		velocity = Vector2.ZERO
		_update_visuals(delta)
		return
	var player: Player = game.player
	var sees := player.alive and _can_see(player)
	if sees:
		last_known = player.global_position
		if state != State.CHASE:
			state = State.CHASE
			react_t = REACTION / skill
			aim_t = 0.0
			if not alerted:
				alerted = true
				game.alert_nearby(global_position, 260.0, last_known, self)
	match state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			if not _follow_path(120.0, delta):
				_start_search(2.5)
		State.CHASE:
			_chase(delta, sees, player)
		State.SEARCH:
			_search(delta)
	_update_visuals(delta)


func _can_see(p: Player) -> bool:
	var to := p.global_position - global_position
	var d := to.length()
	if d > SIGHT_RANGE:
		return false
	if not alerted and d > CLOSE_SENSE and absf(angle_difference(facing, to.angle())) > HALF_FOV:
		return false
	return game.has_los(global_position, p.global_position)


func _patrol(delta: float) -> void:
	if _follow_path(60.0, delta):
		return
	idle_t -= delta
	facing += sin(idle_t * 1.7) * delta * 0.8
	if idle_t <= 0.0:
		idle_t = randf_range(1.5, 4.0)
		_go_to(level.random_floor_near(home, 4))


func _chase(delta: float, sees: bool, player: Player) -> void:
	var wd := WeaponDB.get_data(weapon_id)
	if not sees:
		aim_t = 0.0
		repath_t -= delta
		if path.is_empty() or repath_t <= 0.0:
			_go_to(last_known)
			repath_t = 0.6
		if not _follow_path(150.0, delta):
			_start_search(3.5)
		return
	path = PackedVector2Array()
	var to := player.global_position - global_position
	_turn_to(to.angle(), delta, TURN_RATE)
	react_t -= delta
	aim_t += delta
	mark_node.queue_redraw()
	if wd["melee"]:
		_tick_swing(delta, player, wd)
		if swing_t < 0.0:
			_move_dir(to.normalized(), 165.0)
			if to.length() < wd["range"] + 6.0 and react_t <= 0.0:
				swing_t = 0.22
		else:
			_move_dir(Vector2.ZERO, 0.0)
		return
	if to.length() > SHOOT_RANGE:
		_move_dir(to.normalized(), 140.0)
	else:
		_move_dir(Vector2.ZERO, 0.0)
	if react_t <= 0.0 and fire_t <= 0.0:
		_shoot(wd)


func _tick_swing(delta: float, player: Player, wd: Dictionary) -> void:
	if swing_t < 0.0:
		return
	swing_t -= delta
	if swing_t >= 0.0:
		return
	swing_t = -1.0
	strike_t = 0.2
	fire_t = 0.5
	var to := player.global_position - global_position
	if to.length() < wd["range"] + 12.0 and absf(angle_difference(facing, to.angle())) < 1.3:
		player.take_hit(to.normalized(), false)


func _shoot(wd: Dictionary) -> void:
	fire_t = maxf(wd["cooldown"] * 3.0, 0.22)
	var loose := 4.0 + AIM_LOOSE * (1.0 - clampf(aim_t * skill / AIM_SETTLE, 0.0, 1.0))
	var muzzle: Vector2 = global_position + Vector2.from_angle(facing) * (10.0 + wd["length"])
	for i in wd["pellets"]:
		var a := facing + deg_to_rad(randf_range(-wd["spread"] - loose, wd["spread"] + loose))
		game.spawn_bullet(muzzle, a, false, get_rid())
	game.spawn_fx("flash", muzzle)
	game.make_noise(global_position, wd["noise"], self)


func _start_search(t: float) -> void:
	state = State.SEARCH
	search_t = t
	path = PackedVector2Array()


func _search(delta: float) -> void:
	search_t -= delta
	if not _follow_path(80.0, delta):
		facing += delta * 2.5
		if randf() < delta * 1.2:
			_go_to(level.random_floor_near(last_known, 3))
	if search_t <= 0.0:
		state = State.PATROL
		path = PackedVector2Array()


## Called by game when a noise reaches this enemy.
func hear(pos: Vector2) -> void:
	if passive or state == State.DEAD or state == State.STUNNED or state == State.CHASE:
		return
	state = State.INVESTIGATE
	last_known = pos
	_turn_to((pos - global_position).angle(), 1.0, 2.0)
	_go_to(pos)


func stun(dir: Vector2, t: float) -> void:
	if state == State.DEAD:
		return
	if state != State.STUNNED:
		_drop_weapon(dir)
	state = State.STUNNED
	stun_t = t
	swing_t = -1.0
	velocity = dir * 260.0
	alerted = true
	_update_visuals()


func _recover() -> void:
	if weapon_id == "":
		var p = game.nearest_pickup(global_position, 90.0)
		if p != null:
			weapon_id = p.weapon_id
			p.queue_free()
		else:
			weapon_id = "fists"
	last_known = game.player.global_position
	_start_search(2.0)


## Melee and executions: drops anyone but a boss outright.
func kill(dir: Vector2) -> void:
	if boss_name == "":
		hp = 1
	_damage(dir)


func _damage(dir: Vector2) -> void:
	if state == State.DEAD:
		return
	if hp > 1:
		# Bosses and contractors soak hits: flinch, turn on the attacker, keep fighting.
		hp -= 1
		alerted = true
		last_known = game.player.global_position
		rig.modulate = Color(1.6, 0.6, 0.6)
		get_tree().create_timer(0.12).timeout.connect(func(): if state != State.DEAD: rig.modulate = Color.WHITE)
		if state != State.CHASE:
			state = State.CHASE
			react_t = 0.2
		return
	_drop_weapon(dir)
	state = State.DEAD
	death_dir = dir
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	game.on_enemy_killed(self, dir)
	rig.lie_down(dir.angle(), Color(0.55, 0.42, 0.42))
	rig.position = dir * 8.0
	_set_mark("")


func take_hit(dir: Vector2, _from_player: bool) -> void:
	_damage(dir)


func _drop_weapon(dir: Vector2) -> void:
	if weapon_id == "" or weapon_id == "fists":
		weapon_id = ""
		return
	var ammo := 0
	if WeaponDB.is_gun(weapon_id):
		ammo = int(ceil(WeaponDB.get_data(weapon_id)["ammo"] * randf_range(0.4, 1.0)))
	var spread := dir.rotated(randf_range(-0.8, 0.8)) * randf_range(60.0, 160.0)
	game.spawn_pickup(weapon_id, ammo, global_position, spread, false)
	weapon_id = ""


func _go_to(target: Vector2) -> void:
	path = level.find_path(global_position, target)
	path_i = 0


func _follow_path(speed: float, delta: float) -> bool:
	while path_i < path.size() and global_position.distance_to(path[path_i]) < 6.0:
		path_i += 1
	if path_i >= path.size():
		path = PackedVector2Array()
		_move_dir(Vector2.ZERO, 0.0)
		return false
	var dir := (path[path_i] - global_position).normalized()
	_move_dir(dir, speed)
	_turn_to(dir.angle(), delta, 7.0)
	return true


func _move_dir(dir: Vector2, speed: float) -> void:
	velocity = dir * speed
	move_and_slide()


func _turn_to(angle: float, delta: float, rate: float) -> void:
	facing = rotate_toward(facing, angle, rate * delta)


func _update_visuals(delta: float = 0.0) -> void:
	if state == State.STUNNED:
		if not rig.lying:
			rig.lie_down(facing + PI * 0.5, Color(0.75, 0.75, 0.9))
		_set_mark("zz")
		return
	if rig.lying:
		rig.get_up()
	strike_t = maxf(0.0, strike_t - delta)
	var swing := 0.0
	if swing_t >= 0.0:
		swing = -1.0 + (0.22 - swing_t) / 0.22 * 2.0
	rig.animate(delta, weapon_id, velocity.length() > 10.0, 1.0 - strike_t / 0.2 if strike_t > 0.0 else -1.0)
	rig.pose(facing, swing)
	match state:
		State.CHASE:
			_set_mark("!")
		State.INVESTIGATE, State.SEARCH:
			_set_mark("?")
		_:
			_set_mark("")


func _set_mark(m: String) -> void:
	if m != mark:
		mark = m
		mark_node.queue_redraw()


func _draw_mark() -> void:
	# Raising the gun: a thin aim line warns Toa before the first shot.
	if state == State.CHASE and react_t > 0.0 and not WeaponDB.get_data(weapon_id)["melee"]:
		var k := 1.0 - react_t / REACTION
		var d := Vector2.from_angle(facing)
		mark_node.draw_line(d * 14.0, d * (14.0 + 160.0 * k), Color(1.0, 0.3, 0.25, 0.35 + 0.4 * k), 1.0)
	if boss_name != "" and state != State.DEAD:
		mark_node.draw_string(LABEL_FONT, Vector2(-30, -30), boss_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(1, 0.5, 0.4))
	if mark == "":
		return
	var col := Color(1.0, 0.35, 0.3) if mark == "!" else (Color(1.0, 0.85, 0.3) if mark == "?" else Color(0.8, 0.8, 1.0))
	mark_node.draw_string(ThemeDB.fallback_font, Vector2(-5, -18), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
