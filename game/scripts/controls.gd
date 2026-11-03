class_name Controls
extends RefCounted
## Registers input actions at runtime so project.godot stays readable.


static func setup() -> void:
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("interact", [KEY_E, KEY_SPACE])
	_keys("swap", [KEY_Q])
	_keys("slot_1", [KEY_1])
	_keys("slot_2", [KEY_2])
	_keys("restart", [KEY_R])
	_keys("rotate", [KEY_R])
	_keys("inventory", [KEY_TAB, KEY_I])
	_keys("look", [KEY_SHIFT])
	_keys("plate", [KEY_F])
	_keys("meds", [KEY_G])
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("throw", MOUSE_BUTTON_RIGHT)


static func _keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


static func _mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
