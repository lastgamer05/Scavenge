extends SceneTree
## Headless smoke tests run by CI before the web export.

var failures := 0


func _init() -> void:
	_test_scripts_compile()
	_test_map()
	_test_grid()
	print("tests finished: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + msg)


func _test_scripts_compile() -> void:
	for path in ["res://scripts/game.gd", "res://scripts/level.gd", "res://scripts/player.gd",
			"res://scripts/enemy.gd", "res://scripts/bullet.gd", "res://scripts/pickup.gd",
			"res://scripts/fx.gd", "res://scripts/decals.gd", "res://scripts/hud.gd",
			"res://scripts/weapons.gd", "res://scripts/controls.gd", "res://scripts/roof.gd",
			"res://scripts/items.gd", "res://scripts/inv_grid.gd", "res://scripts/loot_container.gd",
			"res://scripts/inventory_ui.gd", "res://scripts/lights.gd", "res://scripts/light_source.gd",
			"res://scripts/extract_zone.gd", "res://scripts/save_data.gd", "res://scripts/hideout.gd",
			"res://scripts/hideout_hud.gd", "res://scripts/npc.gd", "res://scripts/pixel_art.gd",
			"res://scripts/character_rig.gd", "res://scripts/story.gd", "res://scripts/ally.gd",
			"res://scripts/door.gd", "res://scripts/story_marker.gd", "res://scripts/prologue_director.gd"]:
		var s := load(path) as Script
		_check(s != null and s.can_instantiate(), "script does not compile: " + path)
	_check(load("res://scenes/main.tscn") is PackedScene, "main scene does not load")
	_check(load("res://scenes/hideout.tscn") is PackedScene, "hideout scene does not load")
	for id in Story.MEMORIES:
		_check(id.begins_with("decode_") or ItemDB.DATA.has(id), "memory without a recorder item: " + id)
	for q in Story.QUESTS:
		for id in q["need"]:
			_check(ItemDB.DATA.has(id), "quest needs unknown item " + id)
		_check(q["memory"] == "" or Story.MEMORIES.has(q["memory"]), "quest memory missing: " + q["memory"])


func _test_map() -> void:
	for path in ["res://data/maps/test_yard.txt", "res://data/maps/ruins.txt", "res://data/maps/facility.txt"]:
		_test_map_file(path)
	var ruins := Level.new()
	ruins.load_from_file("res://data/maps/ruins.txt")
	_check(ruins.extract_groups.size() == 4, "ruins has all four extraction kinds")
	_check(ruins.player_cells.size() > 1, "ruins has several spawns")
	_check(ruins.buildings.size() >= 10, "ruins buildings detected: %d" % ruins.buildings.size())
	_check(not ruins.lamp_cells.is_empty() and not ruins.fire_cells.is_empty(), "ruins has lamps and fires")
	for c in ruins.player_cells:
		for kind in ruins.extract_groups:
			var target: Vector2i = ruins.extract_groups[kind][0]
			_check(not ruins.find_path(ruins.cell_to_world(c), ruins.cell_to_world(target)).is_empty(),
				"spawn %s cannot reach %s" % [c, kind])
	ruins.free()


func _test_map_file(path: String) -> void:
	var level := Level.new()
	level.load_from_file(path)
	_check(level.width > 0 and level.height > 0, "map is empty")
	_check(not level.enemy_spawns.is_empty(), "map has no enemies")
	_check(not level.extract_cells.is_empty(), "map has no extraction")
	var start := level.cell_to_world(level.player_cell)
	for c in level.extract_cells:
		_check(not level.find_path(start, level.cell_to_world(c)).is_empty(), "extraction unreachable at %s" % c)
	_check(not level.container_spawns.is_empty(), "map has no containers")
	for s in level.enemy_spawns + level.pickup_spawns + level.container_spawns:
		_check(not level.find_path(start, level.cell_to_world(s[0])).is_empty(), "spawn unreachable at %s" % s[0])
	for id in level.pickup_spawns.map(func(s): return s[1]) + level.enemy_spawns.map(func(s): return s[1]):
		_check(WeaponDB.DATA.has(id), "unknown weapon id: " + id)
	level.free()


func _test_grid() -> void:
	var g := InvGrid.new(4, 3)
	var rifle := ItemDB.make("rifle")
	_check(g.add_at(rifle, 0, 0, false), "4x1 rifle fits on top row")
	_check(not g.fits(ItemDB.make("cash"), 2, 0, false), "overlap rejected")
	_check(not g.fits(ItemDB.make("rifle"), 1, 1, false), "out of bounds rejected")
	_check(g.fits(ItemDB.make("rifle"), 0, 1, false), "second row free")
	var laptop := ItemDB.make("laptop")
	_check(g.add_at(laptop, 2, 1, false), "2x2 laptop fits bottom right")
	_check(g.item_at(Vector2i(3, 2)) == laptop, "item_at finds laptop")
	var smg := ItemDB.make("smg")
	_check(not g.auto_add(smg), "3x2 smg does not fit in remaining 2x2")
	g.remove(laptop)
	_check(g.auto_add(smg), "smg fits after removing laptop")
	_check(ItemDB.size_of(ItemDB.make("rifle"), true) == Vector2i(1, 4), "rotation swaps size")
	_check(g.total_value() == ItemDB.value_of(rifle) + ItemDB.value_of(smg), "total value")
	for kind in ItemDB.LOOT:
		for id in ItemDB.LOOT[kind]["pool"]:
			_check(ItemDB.DATA.has(id), "loot pool has unknown item " + id)
	for id in WeaponDB.DATA:
		_check(id == "fists" or ItemDB.DATA.has(id), "weapon missing from item table: " + id)
