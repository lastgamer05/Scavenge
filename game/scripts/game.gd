extends Node2D
## Phase 1 run: load the map, spawn everything, track kills, death and extraction.

const MAP_PATH := "res://data/maps/test_yard.txt"
const EXTRACT_TIME := 3.0
const CAMERA_ZOOM := 1.6

var level: Level
var player: Player
var decals: Decals
var entities: Node2D
var fx_layer: Node2D
var camera: Camera2D
var hud: Hud
var state := "play"  # play, dead, extracted
var extract_t := 0.0
var run_time := 0.0
var kills := 0
var total_enemies := 0
var shake := 0.0


func _ready() -> void:
	Controls.setup()
	randomize()
	level = Level.new()
	level.load_from_file(MAP_PATH)
	add_child(level)
	level.build()

	decals = Decals.new()
	add_child(decals)
	entities = Node2D.new()
	add_child(entities)
	fx_layer = Node2D.new()
	add_child(fx_layer)

	for s in level.pickup_spawns:
		var id: String = s[1]
		spawn_pickup(id, WeaponDB.get_data(id).get("ammo", 0), level.cell_to_world(s[0]), Vector2.ZERO, false)
	for s in level.enemy_spawns:
		var e := Enemy.new()
		e.game = self
		e.level = level
		e.weapon_id = s[1]
		e.position = level.cell_to_world(s[0])
		entities.add_child(e)
		total_enemies += 1

	player = Player.new()
	player.game = self
	player.position = level.cell_to_world(level.player_cell)
	entities.add_child(player)

	camera = Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.position = player.position
	add_child(camera)
	camera.make_current()

	hud = Hud.new()
	hud.game = self
	add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(delta: float) -> void:
	if state != "play" and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if state == "play":
		run_time += delta
		if level.is_extract(level.world_to_cell(player.global_position)):
			extract_t += delta
			if extract_t >= EXTRACT_TIME:
				_on_extracted()
		else:
			extract_t = 0.0

	# Look-ahead toward the cursor, computed in screen space to avoid camera feedback.
	var vp := get_viewport()
	var screen_off := vp.get_mouse_position() - vp.get_visible_rect().size * 0.5
	var look := 0.75 if Input.is_action_pressed("look") else 0.3
	camera.position = player.global_position + screen_off / CAMERA_ZOOM * look
	shake = maxf(0.0, shake - delta * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake


func spawn_bullet(pos: Vector2, angle: float, from_player: bool, shooter: RID) -> void:
	var b := Bullet.new()
	b.game = self
	b.position = pos
	b.velocity = Vector2.from_angle(angle) * Bullet.SPEED
	b.from_player = from_player
	b.exclude = [shooter]
	fx_layer.add_child(b)


func spawn_pickup(id: String, ammo: int, pos: Vector2, vel: Vector2, thrown: bool) -> void:
	var p := WeaponPickup.new()
	p.game = self
	p.weapon_id = id
	p.ammo = ammo
	p.position = pos
	p.velocity = vel
	p.thrown = thrown
	entities.add_child(p)
	entities.move_child(p, 0)


func spawn_fx(kind: String, pos: Vector2, radius: float = 0.0, life: float = 0.0) -> void:
	var f := FX.new()
	f.kind = kind
	f.position = pos
	f.radius = radius if radius > 0.0 else randf() * TAU
	f.life = life if life > 0.0 else (0.12 if kind == "flash" else 0.25)
	fx_layer.add_child(f)


func nearest_pickup(pos: Vector2, max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.is_queued_for_deletion() or p.thrown:
			continue
		var d := pos.distance_to(p.global_position)
		if d < best_d:
			best = p
			best_d = d
	return best


func nearest_downed(pos: Vector2, max_dist: float) -> Node:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_down() and pos.distance_to(e.global_position) < max_dist:
			return e
	return null


func has_los(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Noise travels through walls at reduced range.
func make_noise(pos: Vector2, radius: float, source: Node) -> void:
	if radius >= 150.0:
		spawn_fx("noise", pos, radius, 0.5)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == source or e.is_dead():
			continue
		var d := pos.distance_to(e.global_position)
		if d > radius:
			continue
		if d > radius * 0.6 and not has_los(pos, e.global_position):
			continue
		e.hear(pos)


func alert_nearby(pos: Vector2, radius: float, target: Vector2, source: Node) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != source and not e.is_dead() and pos.distance_to(e.global_position) < radius:
			e.hear(target)


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func toast(text: String) -> void:
	hud.toast(text)


func on_enemy_killed(e: Enemy, dir: Vector2) -> void:
	kills += 1
	decals.add_blood(e.global_position, dir)
	entities.move_child(e, 0)
	add_shake(5.0)
	if kills == total_enemies:
		toast("구역 정리 완료 — 탈출 지점으로")


func on_player_died(dir: Vector2) -> void:
	state = "dead"
	extract_t = 0.0
	decals.add_blood(player.global_position, dir)
	add_shake(12.0)


func _on_extracted() -> void:
	state = "extracted"
	player.set_physics_process(false)
