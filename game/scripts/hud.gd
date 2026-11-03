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


class ZoneMarkers extends Control:
	var hud: Hud

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var game = hud.game
		if game.state != "play" or game.inventory.visible:
			return
		var font := get_theme_default_font()
		var xf := get_viewport().get_canvas_transform()
		var view := Rect2(Vector2(40, 90), size - Vector2(80, 180))
		var me: Vector2 = game.player.global_position
		for z in get_tree().get_nodes_in_group("extracts") + get_tree().get_nodes_in_group("objectives"):
			var col := Color(1.0, 0.85, 0.3)
			if z.kind != "objective":
				col = Color(0.4, 1.0, 0.55) if z.is_open(game) or z.kind == "flare" and z.flare_state == "idle" else Color(1.0, 0.55, 0.45)
				if z.kind == "flare" and z.flare_state == "gone":
					col = Color(0.6, 0.6, 0.6)
			_draw_marker(font, view, xf, me, z, col)

	## A label over a visible point, or an arrow at the screen edge pointing toward it.
	func _draw_marker(font: Font, view: Rect2, xf: Transform2D, me: Vector2, z: Node2D, col: Color) -> void:
		var p: Vector2 = xf * z.global_position
		var dist := int(me.distance_to(z.global_position) / Level.CELL)
		var label := "%s  %dm" % [z.title, dist]
		if view.has_point(p):
			draw_string(font, p + Vector2(-60, -36), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, col)
			return
		var center := size * 0.5
		var dir := (p - center).normalized()
		var edge := center + dir * minf(absf(view.size.x * 0.5 / dir.x) if dir.x != 0.0 else 1e9,
			absf(view.size.y * 0.5 / dir.y) if dir.y != 0.0 else 1e9)
		var tip := edge + dir * 12.0
		draw_colored_polygon(PackedVector2Array([tip, edge + dir.rotated(2.5) * 10.0, edge + dir.rotated(-2.5) * 10.0]), col)
		draw_string(font, edge - dir * 22.0 + Vector2(-60, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, col)

class SoundPings extends Control:
	## Arcs around Toa pointing at what she hears but cannot see (gunshots red, footsteps grey)
	## and at where a hit came from (a wide red flash). Each keeps its world position, so the arc
	## turns as she moves.
	const LIFE := {"shot": 1.2, "step": 0.5, "hit": 0.9}
	var hud: Hud
	var pings: Array = []  # [world pos, kind, time left]

	func _process(delta: float) -> void:
		for pg in pings:
			pg[2] -= delta
		pings = pings.filter(func(pg): return pg[2] > 0.0)
		queue_redraw()

	func _draw() -> void:
		var game = hud.game
		if game.state != "play" or game.inventory.visible:
			return
		var xf := get_viewport().get_canvas_transform()
		var me: Vector2 = xf * game.player.global_position
		for pg in pings:
			var kind: String = pg[1]
			var k: float = pg[2] / LIFE[kind]
			var a: float = (xf * (pg[0] as Vector2) - me).angle()
			match kind:
				"step":
					draw_arc(me, 52.0, a - 0.3, a + 0.3, 12, Color(0.85, 0.85, 0.85, 0.5 * k), 2.0)
				"shot":
					var col := Color(1.0, 0.45, 0.35, 0.9 * k)
					draw_arc(me, 64.0, a - 0.3, a + 0.3, 12, col, 4.0)
					draw_colored_polygon(PackedVector2Array([me + Vector2.from_angle(a) * 74.0,
						me + Vector2.from_angle(a - 0.12) * 66.0, me + Vector2.from_angle(a + 0.12) * 66.0]), col)
				"hit":
					draw_arc(me, 84.0, a - 0.6, a + 0.6, 20, Color(1.0, 0.15, 0.1, 0.85 * k), 8.0)


var game: Node
var subtitle_label: Label
var subtitle_t := 0.0
var objective_label: Label
var slots_label: Label
var info_label: Label
var prompt_label: Label
var center_label: Label
var toast_label: Label
var toast_t := 0.0
var tutorial_label: Label  # combat lesson instruction, set by CombatTutorial
var pings: SoundPings


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
	tutorial_label = _centered(22, 0.1)
	tutorial_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	var hint := _label(22, Vector2(20, 0))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20
	hint.offset_top = -44
	hint.offset_bottom = -12
	hint.text = "WASD 이동  좌클릭 공격  우클릭 던지기  E 줍기/처형  Tab 가방  Q 교체  F 방탄판  G 치료  Shift 멀리 보기"
	hint.modulate = Color(1, 1, 1, 0.7)
	subtitle_label = _centered(22, 0.84)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	objective_label = _label(11, Vector2(0, 0))
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objective_label.offset_left = -520
	objective_label.offset_right = -20
	objective_label.offset_top = 52
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	var markers := ZoneMarkers.new()
	markers.hud = self
	markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(markers)
	pings = SoundPings.new()
	pings.hud = self
	pings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pings)
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


func say(who: String, text: String) -> void:
	subtitle_label.text = "%s: %s" % [who, text]
	subtitle_t = 5.0


## Something Toa heard but cannot see ("shot", "step"), or where a hit came from ("hit").
func ping(pos: Vector2, kind: String) -> void:
	pings.pings.append([pos, kind, SoundPings.LIFE[kind]])


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
	var plates := p.bag.items.filter(func(i): return i["id"] == "plate").size()
	lines.append("체력 %s%s   방탄판 %s (+%d)" % ["■".repeat(p.hp), "□".repeat(Player.MAX_HP - p.hp),
		"■" if p.armor else "□", plates])
	lines.append("가방 %.1fkg   $%d" % [game.carried_weight(), game.carried_value()])
	if game.speed_mult() < 1.0:
		lines.append("과적: 이동속도 %d%%" % roundi(game.speed_mult() * 100.0))
	slots_label.text = "\n".join(lines)

	var secs := int(game.run_time)
	var left := maxi(0, ceili(game.time_left))
	info_label.text = "처치 %d/%d    남은 시간 %02d:%02d" % [game.kills, game.total_enemies, left / 60, left % 60]
	info_label.modulate = Color(1, 0.45, 0.4) if game.time_left < game.raid_time - game.reinforce_after else Color.WHITE
	if game.mode == "prologue":
		info_label.text = "작전 '회수' — 붕괴 진원지"
		info_label.modulate = Color.WHITE

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
			"story":
				prompt_label.text = target["node"].interact_hint(p.global_position)
		if game.active_zone != null:
			var reason: String = game.active_zone.block_reason(game)
			prompt_label.text = "[%s]  %s" % [game.active_zone.title, reason if reason != "" else "탈출 가능"]
		if p.use_id != "":
			prompt_label.text = "%s  %.1f" % ["방탄판 끼우는 중..." if p.use_id == "plate" else "치료 중...", p.use_t]
		if game.inventory.visible:
			prompt_label.text = ""
		if game.extract_t > 0.0:
			prompt_label.text = "탈출 중...  %.1f" % (game.EXTRACT_TIME - game.extract_t)

	match game.state:
		"dead":
			var why: String = game.death_reason if game.death_reason != "" else "사망"
			center_label.text = "%s\n\n들고 있던 $%d 어치를 잃었습니다 (안전 파우치는 남았다)\n\n[E] 은신처로 귀환" % [why, game.carried_value()]
		"extracted":
			center_label.text = "탈출 성공 — %s\n\n회수 가치 $%d  (%d개)\n처치 %d/%d    시간 %02d:%02d\n\n[E] 은신처로 귀환" % [
				game.active_zone.title, game.extracted_value, game.extracted_count, game.kills, game.total_enemies, secs / 60, secs % 60]
		_:
			center_label.text = ""

	toast_t -= delta
	toast_label.modulate.a = clampf(toast_t, 0.0, 1.0)
	subtitle_t -= delta
	subtitle_label.modulate.a = clampf(subtitle_t, 0.0, 1.0)
	objective_label.text = Story.objective_text() if game.mode != "prologue" else ""
