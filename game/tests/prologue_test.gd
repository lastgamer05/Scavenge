extends SceneTree
## Headless prologue run: door code, sealed case, rooftop bombing, waking up with the core.

var frame := 0
var game: Node
var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	SaveData.loaded = false
	SaveData.ensure_loaded()
	SaveData.next_raid = "prologue"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1


func _process(_delta: float) -> bool:
	frame += 1
	var d: PrologueDirector = game.director
	var p: Player = game.player
	match frame:
		5:
			for e in get_nodes_in_group("enemies"):
				e.set_physics_process(false)
			_check(game.mode == "prologue" and d != null, "prologue mode with a director")
			_check(d.allies.size() == 3, "three teammates")
			_check(p.slots[0] != null and p.slots[0]["id"] == "rifle", "Toa starts with contractor gear")
			_check(get_nodes_in_group("extracts").is_empty(), "no normal extraction points in the prologue")
			p.global_position = d.door.center() + Vector2(0, 30)
			_check(game.interact_target(p.global_position).get("type", "") == "story", "door is interactable")
			p.interact()
			_check(d.door.open and d.stage == "case", "the door code opens the vault")
			p.global_position = d.case_pos + Vector2(10, 0)
			p.interact()
			_check(p.bag.items.any(func(i): return i["id"] == "sealed_case"), "sealed case goes into the bag")
			_check(d.stage == "roof", "objective moves to the roof")
			var pad: Array = game.level.extract_groups["gate"]
			p.global_position = game.level.cell_to_world(pad[0])
		10:
			_check(d.stage == "bombing", "stepping on the helipad starts the bombing")
			# Fast-forward the cutscene instead of waiting real seconds.
			for i in 12:
				d._tick_bombing(0.5)
			_check(d.stage in ["after", "done"], "bombing fades into the aftermath: " + d.stage)
			_check(d.allies.all(func(a): return a.down), "teammates fall in the bombing")
			d.finish()
			_check(SaveData.prologue_done and SaveData.intro_pending, "prologue marked done, intro queued")
			_check(SaveData.pouch.size() == 1 and SaveData.pouch[0]["id"] == "core", "Toa wakes with only the core in the pouch")
			_check(SaveData.bag.is_empty(), "everything else is gone")
			print("prologue finished: %d failure(s)" % failures)
			quit(1 if failures > 0 else 0)
	return false
