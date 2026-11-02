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
			p._interact()
		55:
			_check(target2.is_dead(), "execute kills downed enemy")
			var shooter: Enemy = null
			for e in _enemies():
				if not e.is_dead() and WeaponDB.is_gun(e.weapon_id):
					shooter = e
					break
			p.global_position = shooter.global_position + Vector2.from_angle(shooter.facing) * 100.0
		200:
			_check(not p.alive and game.state == "dead", "enemy shoots player dead")
			print("sim finished: %d failure(s)" % failures)
			quit(1 if failures > 0 else 0)
	return false
