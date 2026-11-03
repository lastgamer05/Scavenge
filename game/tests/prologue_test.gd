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
			_check(d.stage == "cutscene", "stepping on the helipad starts the rooftop cutscene")
			_check(not game.hud.visible and game.cam_focus != null, "cutscene hides the HUD and takes the camera")
			# Fast-forward the cutscene instead of waiting real seconds.
			for i in 60:
				d.tick_cutscene(0.4)
				if i == 39:
					_check(d.dots.size() > 0, "target designators light up before the strike")
			_check(d.stage == "after", "cutscene fades into the aftermath: " + d.stage)
			_check(d.allies.all(func(a): return a.down), "teammates fall in the bombing")
			_check(not d.allies.has(d.leon), "Leon is gone before the bombs land")
			_check(Engine.time_scale == 1.0, "slow motion ends")
			d.finish()
			_check(SaveData.prologue_done and SaveData.intro_pending, "prologue marked done, intro queued")
			_check(SaveData.pouch.size() == 1 and SaveData.pouch[0]["id"] == "core", "Toa wakes with only the core in the pouch")
			_check(SaveData.bag.is_empty(), "everything else is gone")
			_test_replay()
			print("prologue finished: %d failure(s)" % failures)
			quit(1 if failures > 0 else 0)
	return false


func _test_replay() -> void:
	var memories_before := SaveData.memories.size()
	SaveData.bag = [ItemDB.make("goldbar")]
	SaveData.prologue_replay = true
	game.director.stage = "after"
	game.director.finish()
	_check(not SaveData.prologue_replay and SaveData.next_raid == "outskirts", "replay ends back in raid mode")
	_check(SaveData.bag.size() == 1 and SaveData.memories.size() == memories_before, "replay leaves the save alone")
