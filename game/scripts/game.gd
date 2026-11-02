extends Node2D
## One raid: load the map, spawn everything, track kills, loot, death and extraction.

const MAP_PATH := "res://data/maps/ruins.txt"
const EXTRACT_TIME := 3.0
const ZOOM_OUTDOOR := 1.5  # x2 art scale = 3 screen pixels per art pixel
const ZOOM_INDOOR := 2.0
const RAID_TIME := 900.0
const REINFORCE_AFTER := 600.0
const REINFORCE_EVERY := 45.0

var level: Level
var player: Player
var decals: Decals
var entities: Node2D
var fx_layer: Node2D
var camera: Camera2D
var hud: Hud
var inventory: InventoryUI
var roof_layer: Node2D
var player_light: PointLight2D
var active_zone: ExtractZone = null
var time_left := RAID_TIME
var reinforce_t := REINFORCE_EVERY
var death_reason := ""
var combat := true
var state := "play"  # play, dead, extracted
var extract_t := 0.0
var run_time := 0.0
var kills := 0
var total_enemies := 0
var shake := 0.0
var extracted_value := 0
var extracted_count := 0


func _ready() -> void:
	Controls.setup()
	Engine.time_scale = 1.0
	randomize()
	add_to_group("game")
	var moon := CanvasModulate.new()
	moon.color = Lights.MOONLIGHT
	add_child(moon)
	level = Level.new()
	level.load_from_file(MAP_PATH)
	add_child(level)
	level.player_cell = level.player_cells.pick_random()

	decals = Decals.new()
	add_child(decals)
	entities = Node2D.new()
	add_child(entities)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	roof_layer = Node2D.new()
	add_child(roof_layer)
	level.build(roof_layer)

	for c in level.lamp_cells:
		_spawn_light("lamp", c)
	for c in level.fire_cells:
		_spawn_light("fire", c)
	for kind in level.extract_groups:
		var z := ExtractZone.new()
		z.setup(kind, level.extract_groups[kind])
		entities.add_child(z)

	for s in level.pickup_spawns:
		var id: String = s[1]
		spawn_pickup(id, WeaponDB.get_data(id).get("ammo", 0), level.cell_to_world(s[0]), Vector2.ZERO, false)
	for s in level.container_spawns:
		var c := LootContainer.new()
		c.setup(s[1])
		c.position = level.cell_to_world(s[0])
		entities.add_child(c)
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
	_load_loadout()
	player_light = Lights.make(Color(0.75, 0.85, 1.0), 280.0, 0.75, true)
	player.add_child(player_light)

	camera = Camera2D.new()
	camera.zoom = Vector2(ZOOM_OUTDOOR, ZOOM_OUTDOOR)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.position = player.position
	add_child(camera)
	camera.make_current()

	hud = Hud.new()
	hud.game = self
	add_child(hud)
	inventory = InventoryUI.new()
	inventory.game = self
	hud.add_child(inventory)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(delta: float) -> void:
	if state != "play" and (Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("interact")):
		_return_to_hideout()
		return
	var cell := level.world_to_cell(player.global_position)
	if state == "play":
		run_time += delta
		_tick_raid_clock(delta)
		_tick_extraction(delta, cell)
	var inside := level.building_at(cell)
	for roof in level.roofs:
		roof.target_alpha = 0.0 if roof.index == inside else 1.0

	# Zoom in indoors; look-ahead toward the cursor, computed in screen space to avoid camera feedback.
	var zoom_target := ZOOM_INDOOR if inside >= 0 else ZOOM_OUTDOOR
	var zoom := move_toward(camera.zoom.x, zoom_target, delta * 1.2)
	camera.zoom = Vector2(zoom, zoom)
	var vp := get_viewport()
	var screen_off := vp.get_mouse_position() - vp.get_visible_rect().size * 0.5
	var look := 0.75 if Input.is_action_pressed("look") else 0.3
	camera.position = player.global_position + screen_off / zoom * look
	shake = maxf(0.0, shake - delta * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake


## Toa enters the raid with whatever the hideout packed.
func _load_loadout() -> void:
	SaveData.ensure_loaded()
	var overflow := []
	player.bag = SaveData.make_grid("bag", SaveData.bag, overflow)
	player.pouch = SaveData.make_grid("pouch", SaveData.pouch, overflow)
	player.slots = [null, null]
	for i in 2:
		if SaveData.slots[i] != null:
			player.slots[i] = SaveData.slots[i].duplicate()
	SaveData.stash.append_array(overflow)


## Inventory moves are free in a raid; the hideout overrides this to buy, sell and donate.
func transfer(_item: Dictionary, _from, _to) -> String:
	return "ok"


func price_hint(_item: Dictionary, _grid) -> String:
	return ""


func _return_to_hideout() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/hideout.tscn")


func _spawn_light(kind: String, c: Vector2i) -> void:
	var l := LightSource.new()
	l.kind = kind
	l.position = level.cell_to_world(c)
	entities.add_child(l)


func zone_at(cell: Vector2i) -> ExtractZone:
	for z in get_tree().get_nodes_in_group("extracts"):
		if z.contains(cell):
			return z
	return null


func _tick_extraction(delta: float, cell: Vector2i) -> void:
	active_zone = zone_at(cell)
	if active_zone != null and active_zone.is_open(self):
		extract_t += delta
		if extract_t >= EXTRACT_TIME:
			_on_extracted()
	else:
		extract_t = 0.0


## Late in the raid Centra sends patrols in from the map edges; at zero Toa is lost.
func _tick_raid_clock(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		death_reason = "시간 초과 — 폐허에서 실종됐다"
		player.take_hit(Vector2.DOWN, false)
		return
	if RAID_TIME - time_left < REINFORCE_AFTER:
		return
	reinforce_t -= delta
	if reinforce_t > 0.0:
		return
	reinforce_t = REINFORCE_EVERY
	var pos := level.random_edge_floor()
	for i in 2:
		var e := Enemy.new()
		e.game = self
		e.level = level
		e.weapon_id = ["pistol", "smg", "rifle"].pick_random()
		e.position = level.random_floor_near(pos, 2)
		e.alerted = true
		e.centra = true
		entities.add_child(e)
		total_enemies += 1
		e.hear(player.global_position)
	if REINFORCE_AFTER + REINFORCE_EVERY > RAID_TIME - time_left:
		toast("센트라 순찰대가 구역에 진입했다")


func _unhandled_input(event: InputEvent) -> void:
	if state != "play" or not player.alive:
		return
	if event.is_action_pressed("inventory"):
		if inventory.visible:
			inventory.close()
		else:
			inventory.open(null)
	elif event.is_action_pressed("interact"):
		if inventory.visible:
			inventory.close()
		else:
			player.interact()
	elif event.is_action_pressed("ui_cancel") and inventory.visible:
		inventory.close()
	elif event.is_action_pressed("rotate") and inventory.visible:
		inventory.rotate_drag()
	else:
		return
	get_viewport().set_input_as_handled()


func carried_weight() -> float:
	var wt := player.bag.total_weight()
	for item in player.slots:
		if item != null:
			wt += ItemDB.weight_of(item)
	return wt


func carried_value() -> int:
	var v := player.bag.total_value()
	for item in player.slots:
		if item != null:
			v += ItemDB.value_of(item)
	return v


## Full speed up to 8kg, slowing to 55% at 26kg and beyond.
func speed_mult() -> float:
	return clampf(1.0 - maxf(carried_weight() - 8.0, 0.0) / 40.0, 0.55, 1.0)


## What E would act on from this position: execute, pickup or search.
func interact_target(pos: Vector2) -> Dictionary:
	var downed = nearest_downed(pos, Player.EXECUTE_RANGE)
	if downed != null:
		return {"type": "execute", "node": downed}
	var zone := zone_at(level.world_to_cell(pos))
	if zone != null and zone.kind == "flare" and zone.flare_state == "idle":
		return {"type": "flare", "node": zone}
	var p = nearest_pickup(pos, Player.PICKUP_RANGE)
	var c = nearest_container(pos, Player.PICKUP_RANGE + 6.0)
	if p != null and (c == null or pos.distance_to(p.global_position) <= pos.distance_to(c.global_position)):
		return {"type": "pickup", "node": p}
	if c != null:
		return {"type": "search", "node": c}
	return {}


func nearest_container(pos: Vector2, max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for c in get_tree().get_nodes_in_group("containers"):
		if c.is_queued_for_deletion():
			continue
		var d := pos.distance_to(c.global_position)
		if d < best_d:
			best = c
			best_d = d
	return best


## Drops an item at Toa's feet: weapons as pickups, everything else into a pile.
func drop_item(item: Dictionary) -> void:
	var pos := player.global_position
	if ItemDB.is_weapon(item["id"]):
		spawn_pickup(item["id"], item["ammo"], pos, Vector2.from_angle(randf() * TAU) * 80.0, false)
		return
	for c in get_tree().get_nodes_in_group("containers"):
		if c.kind == "pile" and c.global_position.distance_to(pos) < 30.0 and c.grid.auto_add(item):
			return
	var pile := LootContainer.new()
	pile.setup("pile", false)
	pile.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	pile.grid.auto_add(item)
	entities.add_child(pile)
	entities.move_child(pile, 0)


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
	var corpse := LootContainer.new()
	corpse.setup("corpse")
	corpse.position = e.global_position
	entities.add_child(corpse)
	add_shake(5.0)
	if kills == total_enemies:
		toast("구역 정리 완료 — 탈출 지점으로")


func on_player_died(dir: Vector2) -> void:
	state = "dead"
	extract_t = 0.0
	inventory.close()
	SaveData.record_raid(false, player.bag, player.pouch, player.slots, carried_value())
	decals.add_blood(player.global_position, dir)
	add_shake(12.0)


func _on_extracted() -> void:
	state = "extracted"
	active_zone.consume(self)
	inventory.close()
	extracted_value = carried_value()
	extracted_count = player.bag.items.size() + player.slots.size() - player.slots.count(null)
	SaveData.record_raid(true, player.bag, player.pouch, player.slots, extracted_value)
	player.set_physics_process(false)
