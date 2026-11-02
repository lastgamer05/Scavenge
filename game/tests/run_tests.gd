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
			"res://scripts/weapons.gd", "res://scripts/controls.gd", "res://scripts/extract_glow.gd",
			"res://scripts/items.gd", "res://scripts/inv_grid.gd", "res://scripts/loot_container.gd",
			"res://scripts/inventory_ui.gd"]:
		var s := load(path) as Script
		_check(s != null and s.can_instantiate(), "script does not compile: " + path)
	_check(load("res://scenes/main.tscn") is PackedScene, "main scene does not load")


func _test_map() -> void:
	var level := Level.new()
	level.load_from_file("res://data/maps/test_yard.txt")
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
