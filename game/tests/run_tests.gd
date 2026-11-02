extends SceneTree
## Headless smoke tests run by CI before the web export.

var failures := 0


func _init() -> void:
	_test_scripts_compile()
	_test_map()
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
			"res://scripts/weapons.gd", "res://scripts/controls.gd", "res://scripts/extract_glow.gd"]:
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
	for s in level.enemy_spawns + level.pickup_spawns:
		_check(not level.find_path(start, level.cell_to_world(s[0])).is_empty(), "spawn unreachable at %s" % s[0])
	for id in level.pickup_spawns.map(func(s): return s[1]) + level.enemy_spawns.map(func(s): return s[1]):
		_check(WeaponDB.DATA.has(id), "unknown weapon id: " + id)
	level.free()
