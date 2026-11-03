class_name PrologueDirector
extends Node
## Runs the prologue on facility.txt: briefing, the vault door Toa somehow knows the code to,
## the sealed case, the rooftop, and the bombing that leaves Toa officially dead.

const SUB_TIME := 3.4
const LINE_TIME := 3.2

var game: Node
var stage := "brief"  # brief, door, case, roof, bombing, after
var door: Door
var case_pos := Vector2.ZERO
var leon: Ally
var allies: Array = []
var marker: StoryMarker
var subs: Array = []  # [speaker, text] queue
var sub_t := 0.0
var t := 0.0
var after_i := -1
var layer: CanvasLayer
var sub_label: Label
var fade: ColorRect
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
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	sub_label = _label(22)
	sub_label.anchor_top = 0.8
	story_label = _label(22)
	story_label.anchor_top = 0.45


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
		game.toast("목표: 옥상 헬기장으로 이동")


func _process(delta: float) -> void:
	_tick_subs(delta)
	match stage:
		"brief":
			if subs.is_empty():
				stage = "door"
		"roof":
			var cell: Vector2i = game.level.world_to_cell(game.player.global_position)
			if game.level.extract_groups.get("gate", []).has(cell):
				_start_bombing()
		"bombing":
			_tick_bombing(delta)
		"after":
			_tick_after(delta)


func _tick_subs(delta: float) -> void:
	if subs.is_empty():
		sub_label.text = ""
		return
	sub_label.text = "%s: %s" % subs[0]
	sub_t += delta
	if sub_t >= SUB_TIME:
		sub_t = 0.0
		subs.pop_front()


func _start_bombing() -> void:
	stage = "bombing"
	t = 0.0
	marker.queue_free()
	game.player.set_physics_process(false)
	game.inventory.close()
	subs.clear()
	sub_t = 0.0
	say(Story.PROLOGUE_ROOF[0], Story.PROLOGUE_ROOF[1])
	# Leon stays behind in the stairwell and is gone when the bombs land.
	leon.queue_free()
	allies.erase(leon)
	for a in allies:
		a.follow_offset = Vector2(-50, randf_range(-40, 40))


func _tick_bombing(delta: float) -> void:
	var before := t
	t += delta
	var center: Vector2 = game.player.global_position
	if t > 1.2 and fmod(t, 0.35) < fmod(before, 0.35):
		var p := center + Vector2(randf_range(-260, 260), randf_range(-200, 200))
		_explode(p)
	if before < 2.0 and t >= 2.0:
		for a in allies:
			a.die(Vector2.from_angle(randf() * TAU))
		_explode(center + Vector2(-40, 10))
		game.player.rig.lie_down(PI * 0.5, Color(0.8, 0.7, 0.7))
	if t > 3.2:
		fade.color.a = clampf((t - 3.2) / 1.5, 0.0, 1.0)
	if t > 5.0:
		stage = "after"
		t = 0.0
		after_i = 0


func _explode(p: Vector2) -> void:
	game.spawn_fx("flash", p, 0.0, 0.5)
	game.spawn_fx("noise", p, 260.0, 0.6)
	game.add_shake(16.0)
	var light := Lights.make(Color(1.0, 0.55, 0.25), 320.0, 2.2, false)
	light.position = p
	game.fx_layer.add_child(light)
	game.get_tree().create_timer(0.35).timeout.connect(light.queue_free)
	game.decals.add_blood(p, Vector2.ZERO)


func _tick_after(delta: float) -> void:
	t += delta
	if after_i < Story.PROLOGUE_AFTER.size():
		story_label.text = Story.PROLOGUE_AFTER[after_i]
		story_label.modulate.a = clampf(minf(t, LINE_TIME - t) * 2.0, 0.0, 1.0)
		if t >= LINE_TIME:
			t = 0.0
			after_i += 1
		return
	finish()


## Prologue over: Toa wakes in the hideout with only the core.
func finish() -> void:
	if stage == "done":
		return
	stage = "done"
	if SaveData.prologue_replay:
		# Replay from the hideout's secret code: go home with the save untouched.
		SaveData.prologue_replay = false
		SaveData.next_raid = "ruins"
	else:
		SaveData.finish_prologue()
	Engine.time_scale = 1.0
	if game.is_inside_tree():
		game.get_tree().change_scene_to_file.call_deferred("res://scenes/hideout.tscn")
