class_name HideoutHud
extends CanvasLayer
## Money, Bapas standing, context prompt, toasts and the NPC dialogue box.

var hideout: Node
var info_label: Label
var prompt_label: Label
var toast_label: Label
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var toasts: Array = []  # [text, time_left]


func _ready() -> void:
	info_label = _label(22)
	info_label.position = Vector2(20, 16)
	prompt_label = _label(22)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.anchor_top = 0.62
	toast_label = _label(22)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.anchor_top = 0.1

	dialog_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.06, 0.92)
	style.border_color = Color(0.55, 0.42, 0.28)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	dialog_panel.add_theme_stylebox_override("panel", style)
	dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dialog_panel.offset_left = -420
	dialog_panel.offset_right = 420
	dialog_panel.offset_top = -150
	dialog_panel.offset_bottom = -30
	var box := VBoxContainer.new()
	dialog_panel.add_child(box)
	dialog_name = Label.new()
	dialog_name.add_theme_font_size_override("font_size", 22)
	dialog_name.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	box.add_child(dialog_name)
	dialog_text = Label.new()
	dialog_text.add_theme_font_size_override("font_size", 22)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(dialog_text)
	var hint := Label.new()
	hint.text = "[E] 계속"
	hint.add_theme_font_size_override("font_size", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)
	dialog_panel.visible = false
	add_child(dialog_panel)

	var help := _label(11)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 20
	help.offset_top = -30
	help.text = "WASD 이동   E 대화/열기   Tab 가방   동쪽 터널: 출격"
	help.modulate = Color(1, 1, 1, 0.7)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func toast(text: String) -> void:
	toasts.append([text, 2.8])
	if toasts.size() > 3:
		toasts.pop_front()


func show_dialog(who: String, text: String) -> void:
	dialog_name.text = who
	dialog_text.text = text
	dialog_panel.visible = true


func hide_dialog() -> void:
	dialog_panel.visible = false


func _process(delta: float) -> void:
	var next := SaveData.next_level_at()
	var standing := "바파스 Lv.%d  (기부 %d%s)" % [SaveData.level(), SaveData.donated, " / %d" % next if next > 0 else ", 최고"]
	info_label.text = "$%d\n%s\n출격 %d회 · 귀환 %d회" % [SaveData.money, standing, SaveData.raids, SaveData.extracts]
	var obj := Story.objective_text()
	if obj != "":
		info_label.text += "\n\n임무 — " + obj

	prompt_label.text = ""
	if not hideout.inventory.visible:
		var t: Dictionary = hideout.interact_target(hideout.player.global_position)
		match t.get("type", ""):
			"npc":
				prompt_label.text = "E  대화: %s" % t["node"].title()
			"search":
				prompt_label.text = "E  열기: %s" % t["node"].title
			"exit":
				prompt_label.text = "E  출격 — 폐허 구역 (가방 $%d)" % hideout.carried_value()

	var lines := []
	for t in toasts:
		t[1] -= delta
		lines.append(t[0])
	toasts = toasts.filter(func(t): return t[1] > 0.0)
	toast_label.text = "\n".join(lines)
