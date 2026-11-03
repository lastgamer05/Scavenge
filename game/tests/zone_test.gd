extends SceneTree
## Headless checks for the raid zones: map sanity, unlock order, per-zone difficulty,
## and the first raid's combat lesson walked through step by step.

var frame := 0
var game: Node
var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	SaveData.loaded = false
	SaveData.ensure_loaded()
	SaveData.prologue_done = true
	_test_maps()
	_test_unlocks()
	SaveData.next_raid = "outskirts"
	SaveData.combat_tutorial = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1


func _test_maps() -> void:
	for z in Zones.LIST:
		var lv := Level.new()
		lv.load_from_file(z["map"])
		_check(not lv.player_cells.is_empty() and not lv.enemy_spawns.is_empty(), "%s has spawns and enemies" % z["id"])
		_check(lv.extract_groups.size() >= 2, "%s has at least two ways out" % z["id"])
		var reachable := true
		for c in lv.player_cells:
			for kind in lv.extract_groups:
				var target: Vector2i = lv.extract_groups[kind][0]
				if lv.find_path(lv.cell_to_world(c), lv.cell_to_world(target)).is_empty():
					reachable = false
		_check(reachable, "%s: every spawn reaches every exit" % z["id"])
		if z["id"] == "outskirts":
			_check(lv.enemy_spawns.all(func(s): return s[1] in ["bat", "pistol"]), "outskirts: bats and pistols only")
			var far := true
			for s in lv.enemy_spawns:
				for p in lv.player_cells:
					if Vector2(s[0] - p).length() < 20.0:
						far = false
			_check(far, "outskirts: nobody within earshot of the arrival point")
		if z["id"] == "checkpoint":
			_check(lv.enemy_spawns.filter(func(s): return s[1] == "rifle").size() >= 8, "checkpoint: rifle-armed guards")
			_check(lv.container_spawns.filter(func(s): return s[1] == "safe").size() >= 5, "checkpoint: a vault of safes")
		lv.free()
	var counts := Zones.LIST.map(func(z):
		var lv := Level.new()
		lv.load_from_file(z["map"])
		var n := float(lv.enemy_spawns.size()) / (lv.width * lv.height) * 1000.0
		lv.free()
		return snappedf(n, 0.1))
	_check(counts[0] < counts[1] and counts[1] < counts[2], "enemies per 1000 cells climb: %s" % str(counts))
	_check(Zones.LIST[0]["skill"] < Zones.LIST[1]["skill"] and Zones.LIST[1]["skill"] < Zones.LIST[2]["skill"], "enemy skill climbs")


func _test_unlocks() -> void:
	SaveData.zone_extracts = {}
	_check(Zones.unlocked().map(func(z): return z["id"]) == ["outskirts"], "new save: only the outskirts are open")
	SaveData.next_raid = "outskirts"
	var bag := SaveData.make_grid("bag", [], [])
	var pouch := SaveData.make_grid("pouch", [], [])
	SaveData.record_raid(false, bag, pouch, [null, null], 0)
	_check(not Zones.is_unlocked("ruins"), "dying does not open the ruins")
	SaveData.record_raid(true, bag, pouch, [null, null], 0)
	_check(Zones.is_unlocked("ruins") and not Zones.is_unlocked("checkpoint"), "extracting from the outskirts opens the ruins")
	SaveData.next_raid = "ruins"
	SaveData.record_raid(true, bag, pouch, [null, null], 0)
	_check(Zones.is_unlocked("checkpoint"), "extracting from the ruins opens the checkpoint")
	_check(SaveData.last_result.get("zone", "") == "ruins", "the raid result remembers its zone")


func _process(_delta: float) -> bool:
	frame += 1
	if frame != 5:
		return false
	_test_outskirts_raid()
	_test_combat_lesson()
	print("zones finished: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return false


func _test_outskirts_raid() -> void:
	_check(game.mode == "outskirts" and game.raid_time == 600.0, "outskirts raid: 10 minutes")
	var enemies := get_nodes_in_group("enemies")
	_check(enemies.all(func(e): return e.skill == 0.6 and not e.centra), "outskirts enemies are slow scavengers")
	_check(game.tutorial != null and game.tutorial.running(), "first outskirts raid starts the combat lesson")
	var t0: float = game.time_left
	game._tick_raid_clock(5.0)
	_check(game.time_left == t0, "the raid clock waits during the lesson")


func _test_combat_lesson() -> void:
	var t: CombatTutorial = game.tutorial
	var p: Player = game.player
	p.slots = [null, null]
	p.current = 0
	p.global_position += Vector2(130, 0)
	t._process(0.1)
	_check(t.step == 1 and game.nearest_pickup(p.global_position, 200.0) != null, "after moving: a bat is laid out")
	p.slots[0] = ItemDB.make("bat")
	t._process(0.1)
	_check(t.step == 2 and t.target != null and t.target.passive, "bat in hand: a passive target appears")
	var d1: Enemy = t.target
	d1._physics_process(0.1)
	_check(not d1.is_dead() and d1.velocity == Vector2.ZERO, "the target never fights back")
	d1.kill(Vector2.RIGHT)
	t._process(0.1)
	_check(t.step == 3, "clubbed: on to the pistol")
	p.slots[1] = ItemDB.make("pistol")
	t._process(0.1)
	_check(t.step == 3 and game.hud.tutorial_label.text.contains("Q"), "a pistol in the other slot: told to switch")
	p.current = 1
	t._process(0.1)
	_check(t.step == 4 and t.target != d1, "pistol in hand: a second target")
	p.slots[1]["ammo"] = 0
	t._process(0.1)
	_check(t.step == 5 and not t.target.is_dead(), "missed with the last bullet: the throw lesson uses the same target")
	t.target.stun(Vector2.RIGHT, 2.0)
	_check(game.interact_target(t.target.global_position).get("type", "") == "execute", "a knocked-down target can be executed")
	t.target.kill(Vector2.RIGHT)
	t._process(0.1)
	_check(t.step == 6 and not t.running() and SaveData.combat_tutorial, "lesson finished and remembered")
	var t0: float = game.time_left
	game._tick_raid_clock(1.0)
	_check(game.time_left < t0, "the raid clock starts after the lesson")
