class_name PrologueDirector
extends Node
## Runs the prologue on facility.txt: briefing, the vault door Toa somehow knows the code to,
## the sealed case, then the rooftop cutscene: no helicopter, Leon walks away, target
## designators light up the roof, and the bombing leaves Toa officially dead.

const SUB_TIME := 3.4
const LINE_TIME := 3.6
const TYPE_SPEED := 18.0  # characters per second in the aftermath narration
const LETTERBOX := 96.0
const STAIRWELL_CELL := Vector2i(44, 7)
const LEON_EXIT_CELL := Vector2i(40, 13)

var game: Node
var stage := "brief"  # brief, door, case, roof, cutscene, after, done
var door: Door
var case_pos := Vector2.ZERO
var leon: Ally
var allies: Array = []
var marker: StoryMarker
var subs: Array = []  # [speaker, text] queue
var sub_t := 0.0
var t := 0.0
var cues: Array = []  # [time, Callable], fired in order during the cutscene
var after_i := -1
var dots: Array = []
var layer: CanvasLayer
var sub_label: Label
var fade: ColorRect
var flash: ColorRect
var bar_top: ColorRect
var bar_bottom: ColorRect
var story_label: Label


func setup(g: Node, raw_rows: PackedStringArray) -> void:
	game = g
	var door_cells := []
	var mates := []
	for y in raw_rows.size():
		for x in raw_rows[y].length():
			match raw_rows[y][x]:
				"Q":
					door_cells.append(Vector2i(x, y))
				"K":
					case_pos = game.level.cell_to_world(Vector2i(x, y))
				"T":
					mates.append(game.level.cell_to_world(Vector2i(x, y)))
	door = Door.new()
	game.entities.add_child(door)
	door.setup(game.level, door_cells)
	var names := ["팀장 레온", "대원 카스", "대원 미로"]
	var offsets := [Vector2(-40, 0), Vector2(-30, -34), Vector2(-30, 34)]
	for i in mates.size():
		var a := Ally.new()
		a.game = game
		a.display_name = names[i]
		a.follow_offset = offsets[i]
		a.position = mates[i]
		game.entities.add_child(a)
		allies.append(a)
	leon = allies[0]
	game.player.slots = [ItemDB.make("rifle"), ItemDB.make("pistol")]
	marker = StoryMarker.new()
	marker.title = "봉인된 금고"
	marker.position = door.center()
	game.entities.add_child(marker)
	_build_overlay()
	for line in Story.PROLOGUE_BRIEF:
		say(line[0], line[1])
	game.toast("목표: 시설 안의 금고를 찾아라")


func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	flash = _rect(Color(1, 1, 1, 0))
	fade = _rect(Color(0, 0, 0, 0))
	bar_top = _rect(Color.BLACK)
	bar_top.anchor_bottom = 0.0
	bar_top.offset_bottom = 0.0
	bar_bottom = _rect(Color.BLACK)
	bar_bottom.anchor_top = 1.0
	bar_bottom.offset_top = 0.0
	sub_label = _label(22)
	sub_label.anchor_top = 0.8
	story_label = _label(22)
	story_label.anchor_top = 0.45


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r


func _label(size: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	return l


func say(who: String, text: String) -> void:
	subs.append([who, text])


## What E would do right now, for the HUD prompt; empty when nothing.
func interact_hint(pos: Vector2) -> String:
	if stage in ["brief", "door"] and pos.distance_to(door.center()) < 56.0:
		return "E  비밀번호 입력"
	if stage == "case" and pos.distance_to(case_pos) < 44.0:
		return "E  봉인된 케이스 회수"
	return ""


func interact() -> void:
	var pos: Vector2 = game.player.global_position
	if stage in ["brief", "door"] and pos.distance_to(door.center()) < 56.0:
		door.unlock(game.level)
		say(Story.PROLOGUE_DOOR[0], Story.PROLOGUE_DOOR[1])
		stage = "case"
		marker.title = "봉인된 케이스"
		marker.position = case_pos
	elif stage == "case" and pos.distance_to(case_pos) < 44.0:
		if not game.player.bag.auto_add(ItemDB.make("sealed_case")):
			game.toast("가방에 자리가 없다")
			return
		say(Story.PROLOGUE_CASE[0], Story.PROLOGUE_CASE[1])
		stage = "roof"
		marker.title = "옥상 헬기장"
		var pad: Array = game.level.extract_groups.get("gate", [])
		marker.position = game.level.cell_to_world(pad[pad.size() / 2])
		# Leon stays behind at the stairwell. Foreshadowing.
		leon.walk_to(game.level.cell_to_world(STAIRWELL_CELL))
		game.toast("목표: 옥상 헬기장으로 이동")


## Real seconds, so slow motion does not slow the script down.
func _real(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)


func _process(delta: float) -> void:
	var real := _real(delta)
	_tick_subs(real)
	match stage:
		"brief":
			if subs.is_empty():
				stage = "door"
		"roof":
			var cell: Vector2i = game.level.world_to_cell(game.player.global_position)
			if game.level.extract_groups.get("gate", []).has(cell):
				start_cutscene()
		"cutscene":
			tick_cutscene(real)
		"after":
			_tick_after(real)


func _tick_subs(real: float) -> void:
	if subs.is_empty():
		sub_label.text = ""
		return
	sub_label.text = "%s: %s" % subs[0]
	sub_t += real
	if sub_t >= SUB_TIME and stage != "cutscene":
		sub_t = 0.0
		subs.pop_front()


## Cutscene subtitles are timed by the cue list instead of the queue.
func _cue_line(who: String, text: String) -> void:
	subs = [[who, text]]
	sub_t = 0.0


func start_cutscene() -> void:
	if stage == "cutscene":
		return
	stage = "cutscene"
	game.hide_roofs = true
	t = 0.0
	marker.queue_free()
	game.inventory.close()
	game.player.set_physics_process(false)
	game.hud.visible = false
	game.cam_focus = game.player.global_position
	game.cam_zoom = 2.2
	subs.clear()
	var toa: Vector2 = game.player.global_position
	var huddle := [Vector2(-34, -26), Vector2(-34, 26)]
	for i in range(1, allies.size()):
		allies[i].walk_to(toa + huddle[i - 1])
	var leon_spot: Vector2 = game.level.cell_to_world(STAIRWELL_CELL)
	leon.walk_to(leon_spot)
	cues = []
	for line in Story.PROLOGUE_ROOF:
		cues.append([line[0], _cue_line.bind(line[1], line[2])])
	cues.append_array([
		[5.6, func(): game.cam_focus = leon_spot.lerp(toa, 0.35)],
		[7.4, func(): game.cam_focus = leon_spot; game.cam_zoom = 2.6],
		[12.6, func(): leon.walk_to(game.level.cell_to_world(LEON_EXIT_CELL))],
		[13.4, func(): game.cam_focus = toa; game.cam_zoom = 2.0],
		[14.4, func(): _target_dot(toa + Vector2(150, -60))],
		[14.8, func(): _target_dot(toa + Vector2(-120, 80))],
		[15.1, func(): _target_dot(toa + Vector2(60, 110))],
		[15.4, func(): _target_dot(toa + Vector2(-60, -100))],
		[15.6, func(): _target_dot(toa + Vector2(10, 0))],
		[17.6, func(): _boom(toa + Vector2(220, -120), 70.0)],
		[18.1, func(): _boom(toa + Vector2(-200, 90), 80.0)],
		[18.6, func(): leon.queue_free(); allies.erase(leon)],
		[18.7, _final_blast],
		[20.4, func(): Engine.time_scale = 1.0],
	])
	cues.sort_custom(func(x, y): return x[0] < y[0])


func tick_cutscene(real: float) -> void:
	t += real
	var bars := clampf(t / 0.8, 0.0, 1.0) * LETTERBOX
	bar_top.offset_bottom = bars
	bar_bottom.offset_top = -bars
	flash.color.a = maxf(0.0, flash.color.a - real * 1.2)
	while not cues.is_empty() and t >= cues[0][0]:
		var cue: Array = cues.pop_front()
		cue[1].call()
	for d in dots:
		if is_instance_valid(d):
			d.queue_redraw()
	if t > 20.6:
		fade.color.a = clampf((t - 20.6) / 1.6, 0.0, 1.0)
	if t > 22.6:
		subs.clear()
		bar_top.offset_bottom = 0.0
		bar_bottom.offset_top = 0.0
		stage = "after"
		t = 0.0
		after_i = 0


## A red laser designator dot on the roof, pulsing faster as the strike nears.
func _target_dot(p: Vector2) -> void:
	var dot := Node2D.new()
	dot.position = p
	dot.draw.connect(func():
		var pulse := 0.5 + 0.5 * sin(t * (8.0 + t))
		dot.draw_circle(Vector2.ZERO, 3.0, Color(1, 0.1, 0.1, 1))
		dot.draw_arc(Vector2.ZERO, 8.0 + pulse * 6.0, 0.0, TAU, 20, Color(1, 0.15, 0.1, 0.8), 1.5))
	var glow := Lights.make(Color(1, 0.1, 0.1), 60.0, 1.2, false)
	dot.add_child(glow)
	game.fx_layer.add_child(dot)
	dots.append(dot)


func _boom(p: Vector2, size: float) -> void:
	game.spawn_fx("boom", p, size, 0.7)
	game.spawn_fx("noise", p, 300.0, 0.6)
	game.add_shake(14.0)
	game.decals.add_blood(p, Vector2.ZERO)


## The strike lands on the team: white-out, slow motion, everyone goes down.
func _final_blast() -> void:
	var toa: Vector2 = game.player.global_position
	for d in dots:
		if is_instance_valid(d):
			d.queue_free()
	dots.clear()
	_boom(toa + Vector2(20, -10), 140.0)
	_boom(toa + Vector2(-60, 40), 110.0)
	flash.color.a = 1.0
	Engine.time_scale = 0.25
	game.add_shake(26.0)
	for a in allies:
		a.die(Vector2.from_angle(randf() * TAU))
	game.player.rig.lie_down(PI * 0.5, Color(0.8, 0.7, 0.7))
	subs.clear()


func _tick_after(real: float) -> void:
	t += real
	if after_i < Story.PROLOGUE_AFTER.size():
		var line: String = Story.PROLOGUE_AFTER[after_i]
		story_label.text = line
		story_label.visible_characters = int(t * TYPE_SPEED)
		story_label.modulate.a = clampf((LINE_TIME + line.length() / TYPE_SPEED - t) * 2.0, 0.0, 1.0)
		if t >= LINE_TIME + line.length() / TYPE_SPEED:
			t = 0.0
			after_i += 1
		return
	finish()


## Prologue over: Toa wakes in the hideout with only the core.
func finish() -> void:
	if stage == "done":
		return
	stage = "done"
	Engine.time_scale = 1.0
	if SaveData.prologue_replay:
		# Replay from the hideout's secret code: go home with the save untouched.
		SaveData.prologue_replay = false
		SaveData.next_raid = "outskirts"
	else:
		SaveData.finish_prologue()
	if game.is_inside_tree():
		game.get_tree().change_scene_to_file.call_deferred("res://scenes/hideout.tscn")
