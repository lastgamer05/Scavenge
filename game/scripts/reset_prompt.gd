class_name ResetPrompt
extends CanvasLayer
## Typing 0000 anywhere (hideout, raid, prologue) asks whether to wipe the save.
## E wipes and starts over from the prologue; Esc cancels. Added as the last child of a
## scene root so it sees input before the scene's own handler.

const CODE := "0000"

var typed := ""
var panel: PanelContainer
var previous_mouse := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.06, 0.95)
	style.border_color = Color(0.8, 0.3, 0.25)
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -80
	panel.offset_bottom = 80
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "기록 초기화\n\n돈, 보관함, 스토리, 열린 지역까지 전부 지우고\n프롤로그부터 다시 시작한다.\n\nE  초기화        Esc  취소"
	panel.add_child(label)
	panel.visible = false
	add_child(panel)


func is_open() -> bool:
	return panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if panel.visible:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("interact"):
			_wipe()
		elif event.is_action_pressed("ui_cancel"):
			panel.visible = false
			Input.mouse_mode = previous_mouse
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var d := digit_of(event)
	if d < 0:
		return
	typed = (typed + str(d)).right(CODE.length())
	if typed == CODE:
		typed = ""
		previous_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		panel.visible = true
		get_viewport().set_input_as_handled()


func _wipe() -> void:
	panel.visible = false
	SaveData.prologue_replay = false
	SaveData.wipe()
	Engine.time_scale = 1.0
	# The hideout sends a fresh save straight to the prologue.
	get_tree().change_scene_to_file.call_deferred("res://scenes/hideout.tscn")


## Top-row digits, numpad digits, or whatever the keyboard layout reports as 0-9.
static func digit_of(ev: InputEventKey) -> int:
	for k in [ev.physical_keycode, ev.keycode]:
		if k >= KEY_0 and k <= KEY_9:
			return k - KEY_0
		if k >= KEY_KP_0 and k <= KEY_KP_9:
			return k - KEY_KP_0
	if ev.unicode >= 48 and ev.unicode <= 57:
		return ev.unicode - 48
	return -1
