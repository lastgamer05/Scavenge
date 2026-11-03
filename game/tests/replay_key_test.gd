extends SceneTree
## Real input path for the hidden replay code: numpad digits pushed through the viewport.

var frame := 0
var hideout: Node


func _initialize() -> void:
	SaveData.enabled = false
	SaveData.loaded = false
	SaveData.ensure_loaded()
	SaveData.prologue_done = true
	hideout = load("res://scenes/hideout.tscn").instantiate()
	root.add_child(hideout)


func _send(digit: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_KP_0 + digit
		ev.keycode = ev.physical_keycode
		ev.pressed = pressed
		root.push_input(ev)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		for d in [3, 0, 7, 1, 9]:
			_send(d)
	if frame == 8:
		var ok := SaveData.prologue_replay and SaveData.next_raid == "prologue"
		print(("ok   " if ok else "FAIL ") + "numpad 0719 through the viewport starts the replay")
		print("replay key finished: %d failure(s)" % (0 if ok else 1))
		quit(0 if ok else 1)
	return false
