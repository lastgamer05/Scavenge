class_name Hud
extends CanvasLayer
## Weapon slots, enemy count, context prompts, end-of-run message and crosshair.


class Crosshair extends Control:
	var hud: Hud

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if hud.game.inventory.visible:
			return
		var m := get_viewport().get_mouse_position()
		var col := Color(1.0, 1.0, 1.0, 0.9)
		draw_arc(m, 7.0, 0.0, TAU, 20, col, 1.5)
		draw_line(m + Vector2(-12, 0), m + Vector2(-4, 0), col, 1.5)
		draw_line(m + Vector2(4, 0), m + Vector2(12, 0), col, 1.5)
		draw_line(m + Vector2(0, -12), m + Vector2(0, -4), col, 1.5)
		draw_line(m + Vector2(0, 4), m + Vector2(0, 12), col, 1.5)
		var t: float = hud.game.extract_t
		if t > 0.0:
			var k: float = t / hud.game.EXTRACT_TIME
			draw_arc(m, 16.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color(0.3, 1.0, 0.5), 3.0)


var game: Node
var slots_label: Label
var info_label: Label
var prompt_label: Label
var center_label: Label
var toast_label: Label
var toast_t := 0.0


func _ready() -> void:
	slots_label = _label(22, Vector2(20, 16))
	info_label = _label(22, Vector2(0, 16))
	info_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.offset_left = -420
	info_label.offset_right = -20
	info_label.offset_top = 16
	info_label.offset_bottom = 56
	prompt_label = _centered(22, 0.68)
	toast_label = _centered(22, 0.76)
	center_label = _centered(44, 0.32)
	var hint := _label(22, Vector2(20, 0))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20
	hint.offset_top = -44
	hint.offset_bottom = -12
	hint.text = "WASD 이동   좌클릭 공격   우클릭 던지기   E 줍기/뒤지기/처형   Tab 가방   Q 무기 교체   Shift 멀리 보기"
	hint.modulate = Color(1, 1, 1, 0.7)
	var cross := Crosshair.new()
	cross.hud = self
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)


func _label(font_size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _centered(font_size: int, y_ratio: float) -> Label:
	var l := _label(font_size, Vector2.ZERO)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.anchor_top = y_ratio
	return l


func toast(text: String) -> void:
	toast_label.text = text
	toast_t = 1.6


func _process(delta: float) -> void:
	var p: Player = game.player
	var lines := []
	for i in 2:
		var w = p.slots[i]
		var mark := "▶ " if i == p.current else "   "
		var txt := "비어 있음"
		if w != null:
			var wd := WeaponDB.get_data(w["id"])
			txt = wd["name"]
			if not wd["melee"]:
				txt += "  %d/%d" % [w["ammo"], wd["ammo"]]
		lines.append("%s[%d] %s" % [mark, i + 1, txt])
	lines.append("")
	lines.append("가방 %.1fkg   $%d" % [game.carried_weight(), game.carried_value()])
	if game.speed_mult() < 1.0:
		lines.append("과적: 이동속도 %d%%" % roundi(game.speed_mult() * 100.0))
	slots_label.text = "\n".join(lines)

	var secs := int(game.run_time)
	info_label.text = "처치 %d/%d    %02d:%02d" % [game.kills, game.total_enemies, secs / 60, secs % 60]

	prompt_label.text = ""
	if game.state == "play":
		var target: Dictionary = game.interact_target(p.global_position)
		match target.get("type", ""):
			"execute":
				prompt_label.text = "E  처형"
			"pickup":
				var pk = target["node"]
				var wd := WeaponDB.get_data(pk.weapon_id)
				var extra := "" if wd["melee"] else "  (%d발)" % pk.ammo
				prompt_label.text = "E  줍기: %s%s" % [wd["name"], extra]
			"search":
				prompt_label.text = "E  뒤지기: %s" % target["node"].title
		if game.inventory.visible:
			prompt_label.text = ""
		if game.extract_t > 0.0:
			prompt_label.text = "탈출 중...  %.1f" % (game.EXTRACT_TIME - game.extract_t)

	match game.state:
		"dead":
			center_label.text = "사망\n\n들고 있던 $%d 어치를 잃었습니다\n\n[R] 다시 시작" % game.carried_value()
		"extracted":
			center_label.text = "탈출 성공\n\n회수 가치 $%d  (%d개)\n처치 %d/%d    시간 %02d:%02d\n\n[R] 다시 하기" % [
				game.extracted_value, game.extracted_count, game.kills, game.total_enemies, secs / 60, secs % 60]
		_:
			center_label.text = ""

	toast_t -= delta
	toast_label.modulate.a = clampf(toast_t, 0.0, 1.0)
