extends SceneTree
## Headless gameplay simulation on the real raid map: combat, looting, roofs, extraction rules.
## Enemies are frozen except the one under test, so the big map does not make results random.

var frame := 0
var game: Node
var failures := 0
var target: Enemy
var target2: Enemy
var shooter: Enemy


func _initialize() -> void:
	SaveData.enabled = false
	SaveData.loaded = false
	SaveData.ensure_loaded()
	SaveData.prologue_done = true
	SaveData.quest = 3  # "옛 팀장": spawns Leon and his guards
	SaveData.quest_given = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1


func _enemies() -> Array:
	return get_nodes_in_group("enemies")


## A floor spot at `dist` from the node with clear line of sight to it.
func _spot_near(node: Node2D, dist: float) -> Vector2:
	for i in 32:
		var spot: Vector2 = node.global_position + Vector2.from_angle(i * TAU / 32.0) * dist
		if not game.level.is_wall(game.level.world_to_cell(spot)) and game.has_los(node.global_position, spot):
			return spot
	return node.global_position + Vector2(dist, 0)


func _process(_delta: float) -> bool:
	frame += 1
	var p: Player = game.player
	match frame:
		5:
			for e in _enemies():
				e.set_physics_process(false)
			target = _enemies()[0]
			p.global_position = _spot_near(target, 120.0)
			p.slots[0] = ItemDB.make("pistol")
			p.current = 0
			p.aim = (target.global_position - p.global_position).angle()
			p._attack(p.slots[0], WeaponDB.get_data("pistol"))
		30:
			_check(target.is_dead(), "pistol shot kills enemy")
			_check(p.slots[0]["ammo"] == 11, "shot uses ammo")
			_check(game.kills == 1, "kill counted")
			_check(game.nearest_pickup(target.global_position, 200.0) != null, "dead enemy dropped weapon")
			target2 = _enemies()[1]
			p.global_position = _spot_near(target2, 90.0)
			p.slots[0] = ItemDB.make("smg", 0)
			p.aim = (target2.global_position - p.global_position).angle()
			p._throw()
		50:
			_check(target2.is_down(), "thrown weapon stuns enemy")
			_check(p.slots[0] == null, "thrown weapon leaves slot")
			p.global_position = target2.global_position + (p.global_position - target2.global_position).normalized() * 20.0
			p.interact()
		55:
			_check(target2.is_dead(), "execute kills downed enemy")
			_test_loot(p)
			_test_extraction(p)
			p.global_position = game.level.cell_to_world(game.level.buildings[0][0])
		58:
			_check(game.level.roofs[0].target_alpha == 0.0, "roof over Toa's building fades")
			_check(game.level.roofs[1].target_alpha == 1.0, "other roofs stay")
			_test_story()
			for e in _enemies():
				if not e.is_dead() and WeaponDB.is_gun(e.weapon_id):
					shooter = e
					break
			shooter.alerted = true
			shooter.set_physics_process(true)
			p.global_position = _spot_near(shooter, 60.0)
		320:
			if p.alive:
				print("debug shooter ", shooter.weapon_id, " state ", shooter.state, " dist ", shooter.global_position.distance_to(p.global_position), " los ", game.has_los(shooter.global_position, p.global_position), " cell ", game.level.world_to_cell(shooter.global_position))
			_check(not p.alive and game.state == "dead", "enemy shoots player dead")
			print("sim finished: %d failure(s)" % failures)
			quit(1 if failures > 0 else 0)
	return false


func _test_loot(p: Player) -> void:
	var crate: LootContainer = null
	for c in get_nodes_in_group("containers"):
		if c.kind == "crate":
			crate = c
			break
	crate.grid.items.clear()
	crate.grid.auto_add(ItemDB.make("goldbar"))
	p.global_position = crate.global_position + Vector2(10, 0)
	p.interact()
	_check(game.inventory.visible and game.inventory.other == crate, "E opens nearby crate")
	_check(is_equal_approx(Engine.time_scale, 0.3), "bag slows time")
	var gold = crate.grid.items[0]
	game.inventory._quick_move(gold, crate.grid)
	_check(p.bag.has(gold) and crate.grid.items.is_empty(), "shift-click moves item into bag")
	_check(game.carried_value() >= 800, "carried value counts bag")
	game.inventory.close()
	_check(not game.inventory.visible and is_equal_approx(Engine.time_scale, 1.0), "closing restores time")
	p.bag.remove(gold)
	game.drop_item(gold)
	var pile = game.nearest_container(p.global_position, 40.0)
	_check(pile != null and pile.kind == "pile" and pile.grid.has(gold), "dropped item lands in a pile")
	for i in 8:
		p.bag.auto_add(ItemDB.make("fuel"))
	_check(game.speed_mult() < 1.0, "heavy bag slows movement")
	p.bag.items.clear()


func _zone(kind: String) -> ExtractZone:
	for z in get_nodes_in_group("extracts"):
		if z.kind == kind:
			return z
	return null


func _test_extraction(p: Player) -> void:
	_check(_zone("gate").is_open(game), "gate is always open")
	var sewer := _zone("sewer")
	for i in 4:
		p.bag.auto_add(ItemDB.make("fuel"))
	_check(not sewer.is_open(game), "sewer blocks a heavy bag")
	p.bag.items.clear()
	p.slots = [null, null]
	_check(sewer.is_open(game), "sewer lets a light bag through")
	var car := _zone("car")
	_check(not car.is_open(game), "car needs fuel")
	p.bag.auto_add(ItemDB.make("fuel"))
	_check(car.is_open(game), "car opens with fuel")
	car.consume(game)
	_check(p.bag.items.is_empty(), "car burns the fuel can")
	var flare := _zone("flare")
	_check(not flare.is_open(game), "flare starts closed")
	p.global_position = game.level.cell_to_world(flare.cells[0])
	_check(game.interact_target(p.global_position).get("type", "") == "flare", "E at flare zone fires flare")
	p.interact()
	_check(flare.flare_state == "waiting", "flare fired")
	flare.flare_t = 0.01
	flare._process(0.02)
	_check(flare.flare_state == "ready" and flare.is_open(game), "helicopter arrives and opens")


func _test_story() -> void:
	var boss: Enemy = null
	for e in _enemies():
		if e.boss_name != "":
			boss = e
	_check(boss != null and boss.hp == 3 and boss.centra, "quest 4 spawns Leon in Centra uniform")
	_check(not get_nodes_in_group("objectives").is_empty(), "quest target gets a marker")
	var caches := get_nodes_in_group("containers").filter(func(c): return c.kind == "cache")
	_check(caches.size() == 4, "four recorder caches in the ruins")
	boss.kill(Vector2.RIGHT)
	boss.kill(Vector2.RIGHT)
	_check(not boss.is_dead() and boss.hp == 1, "Leon survives two hits")
	boss.kill(Vector2.RIGHT)
	_check(boss.is_dead(), "third hit drops Leon")
	var corpse = game.nearest_container(boss.global_position, 40.0)
	_check(corpse != null and corpse.grid.items.any(func(i): return i["id"] == "dogtag"), "Leon's corpse holds the dog tag")
