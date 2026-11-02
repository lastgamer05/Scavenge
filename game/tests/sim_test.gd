extends SceneTree
## Headless gameplay simulation: shoots, throws, executes and gets shot, checking state changes.

var frame := 0
var game: Node
var failures := 0
var target: Enemy
var target2: Enemy


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1


func _enemies() -> Array:
	return get_nodes_in_group("enemies")


func _process(_delta: float) -> bool:
	frame += 1
	var p: Player = game.player
	match frame:
		5:
			target = _enemies()[0]
			p.global_position = target.global_position + Vector2(120, 0)
			p.slots[0] = {"id": "pistol", "ammo": 12}
			p.current = 0
			p.aim = (target.global_position - p.global_position).angle()
			p._attack(p.slots[0], WeaponDB.get_data("pistol"))
		30:
			_check(target.is_dead(), "pistol shot kills enemy")
			_check(p.slots[0]["ammo"] == 11, "shot uses ammo")
			_check(game.kills == 1, "kill counted")
			_check(game.nearest_pickup(target.global_position, 200.0) != null, "dead enemy dropped weapon")
			target2 = _enemies()[1]
			p.global_position = target2.global_position + Vector2(-90, 0)
			p.slots[0] = {"id": "smg", "ammo": 0}
			p.aim = (target2.global_position - p.global_position).angle()
			p._throw()
		50:
			_check(target2.is_down(), "thrown weapon stuns enemy")
			_check(p.slots[0] == null, "thrown weapon leaves slot")
			p.global_position = target2.global_position + Vector2(-20, 0)
			p.interact()
		55:
			_check(target2.is_dead(), "execute kills downed enemy")
			_test_loot(p)
			var shooter: Enemy = null
			for e in _enemies():
				if not e.is_dead() and WeaponDB.is_gun(e.weapon_id):
					shooter = e
					break
			# Stand in clear line of sight; an alerted enemy sees all around.
			shooter.alerted = true
			for i in 16:
				var spot: Vector2 = shooter.global_position + Vector2.from_angle(i * TAU / 16.0) * 100.0
				if not game.level.is_wall(game.level.world_to_cell(spot)) and game.has_los(shooter.global_position, spot):
					p.global_position = spot
					break
		200:
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
