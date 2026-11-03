extends Node2D
## The Bapas hideout in an old metro station: stash, traders, donations, story, and the way out.
## Shares Player and InventoryUI with the raid; transfer() turns bag moves into trades.

const MAP_PATH := "res://data/maps/hideout.txt"
const ROLE_CHARS := {"A": "leader", "W": "weapons", "D": "doctor", "J": "junk", "I": "informant"}
const SHOP_STOCK := ["pistol", "silenced", "smg", "shotgun", "rifle", "bat", "knife"]
const BUY_MARKUP := 1.5
const TALK_RANGE := 52.0
const LINES := {
	"leader": [
		"토아. 기록상 넌 죽은 사람이다. 그래서 쓸모가 있지.",
		"네 파우치에서 나온 데이터 코어. 센트라가 미친 듯이 찾고 있다.",
		"해독하려면 장비와 돈이 필요해. 폐허에서 쓸 만한 걸 가져와.",
		"기부함에 물자를 넣으면 바파스가 커진다. 그만큼 너한테도 돌아가고.",
	],
	"weapons": ["총이 필요하면 사 가. 쓸 만한 총을 가져오면 시세의 90%에 사 주지."],
	"doctor": ["약 있으면 넘겨. 시세보다 넉넉히 쳐줄게. 다른 건 안 받아."],
	"junk": ["뭐든 가져와. 녹이면 다 쓸 데가 있어. 총은 반값이다."],
	"informant": [
		"정문 검문소는 항상 열려 있지만 멀다. 하수도는 짐이 가벼워야 빠져나가.",
		"차는 연료통만 있으면 굴러가. 신호탄은 헬기를 부르지만 온 동네가 다 듣는다.",
		"10분이 넘으면 센트라 순찰대가 들어온다. 15분이면 끝이야. 욕심 부리지 마.",
	],
}

## The Bapas terminal the core is plugged into. Shows every decoded file and recording.
class Decoder extends Node2D:
	var hideout: Node

	func _ready() -> void:
		add_to_group("npcs")
		var spr := Sprite2D.new()
		spr.texture = PixelArt.texture("prop:safe")
		spr.scale = Vector2.ONE * CharacterRig.SCALE
		add_child(spr)

	func title() -> String:
		return "코어 해독기"

	func interact() -> void:
		hideout.show_memories()


var level: Level
var player: Player
var entities: Node2D
var camera: Camera2D
var hud: HideoutHud
var inventory: InventoryUI
var stash: LootContainer
var donate_box: LootContainer
var combat := false
var state := "play"
var extract_t := 0.0
var dialog_npc: Node2D = null  # whoever the dialogue box belongs to (NPC or decoder)
var dialog_lines: Array = []
var dialog_i := 0
var exit_cells: Array = []
var secret := ""  # last digits typed; the vault code from the prologue replays it


func _ready() -> void:
	Controls.setup()
	Engine.time_scale = 1.0
	SaveData.ensure_loaded()
	var mood := CanvasModulate.new()
	mood.color = Color(0.62, 0.56, 0.54)
	add_child(mood)

	var text := FileAccess.get_file_as_string(MAP_PATH)
	level = Level.new()
	level.load_from_text(text)
	add_child(level)
	entities = Node2D.new()
	add_child(entities)
	var roof_layer := Node2D.new()
	add_child(roof_layer)
	level.build(roof_layer)
	level.scatter_decor(8, 0, 7)
	roof_layer.visible = false  # the station is all indoors
	exit_cells = level.extract_groups.get("gate", [])

	for c in level.lamp_cells:
		_spawn_light("lamp", c)
	for c in level.fire_cells:
		_spawn_light("fire", c)

	var rows := text.replace("\r", "").split("\n")
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			var pos := level.cell_to_world(Vector2i(x, y))
			if ROLE_CHARS.has(ch):
				_spawn_npc(ROLE_CHARS[ch], pos)
			elif ch == "S":
				stash = _spawn_box("stash", pos)
			elif ch == "B":
				donate_box = _spawn_box("donate", pos)
			elif ch == "C":
				var d := Decoder.new()
				d.hideout = self
				d.position = pos
				entities.add_child(d)

	player = Player.new()
	player.game = self
	player.position = level.cell_to_world(level.player_cell)
	entities.add_child(player)
	player.add_child(Lights.make(Color(0.95, 0.85, 0.7), 220.0, 0.6, false))

	camera = Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)  # same as the raid outdoors
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.position = player.position
	add_child(camera)
	camera.make_current()

	hud = HideoutHud.new()
	hud.hideout = self
	add_child(hud)
	inventory = InventoryUI.new()
	inventory.game = self
	hud.add_child(inventory)
	_apply_level()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not SaveData.prologue_done:
		# A fresh save starts at ground zero, not here.
		_start_raid.call_deferred("prologue")
		return
	_report_last_raid()
	_collect_recorders()
	if SaveData.intro_pending:
		SaveData.intro_pending = false
		_persist()
		_open_dialog(_leader(), Story.INTRO.duplicate())


func _spawn_light(kind: String, c: Vector2i) -> void:
	var l := LightSource.new()
	l.kind = kind
	l.position = level.cell_to_world(c)
	entities.add_child(l)


func _spawn_npc(role: String, pos: Vector2) -> void:
	var npc := Npc.new()
	npc.role = role
	npc.hideout = self
	npc.position = pos
	entities.add_child(npc)
	var kind: String = {"weapons": "weapon_shop", "doctor": "doctor", "junk": "junk"}.get(role, "")
	if kind != "":
		npc.counter = LootContainer.new()
		npc.counter.setup(kind, false)
		npc.add_child(npc.counter)
		if kind == "weapon_shop":
			_restock(npc.counter.grid)


func _spawn_box(kind: String, pos: Vector2) -> LootContainer:
	var box := LootContainer.new()
	box.setup(kind, false)
	box.position = pos
	box.searched = true
	entities.add_child(box)
	return box


## Grids follow the current Bapas level, so donating can grow the bag, pouch and stash.
func _apply_level() -> void:
	var overflow := []
	player.bag = SaveData.make_grid("bag", SaveData.bag, overflow)
	player.pouch = SaveData.make_grid("pouch", SaveData.pouch, overflow)
	player.slots = [null, null]
	for i in 2:
		if SaveData.slots[i] != null:
			player.slots[i] = SaveData.slots[i].duplicate()
	stash.grid = SaveData.make_grid("stash", SaveData.stash + overflow, [])
	stash.title = "창고 (%dx%d)" % [stash.grid.w, stash.grid.h]


func _persist() -> void:
	SaveData.stash = stash.grid.items.duplicate(true)
	SaveData.store_loadout(player.bag, player.pouch, player.slots)
	SaveData.save()


func _report_last_raid() -> void:
	var r: Dictionary = SaveData.last_result
	if r.is_empty():
		hud.toast("바파스 거점. 리더에게 말을 걸어 보자.")
	elif r["extracted"]:
		hud.toast("귀환 성공 — $%d 어치를 가져왔다" % r["value"])
	else:
		hud.toast("작전 실패 — $%d 어치를 잃었다" % r["value"])
	SaveData.last_result = {}


func _process(delta: float) -> void:
	var vp := get_viewport()
	var screen_off := vp.get_mouse_position() - vp.get_visible_rect().size * 0.5
	camera.position = player.global_position + screen_off / camera.zoom.x * 0.15
	if dialog_npc != null and dialog_npc.global_position.distance_to(player.global_position) > TALK_RANGE * 2.0:
		_end_dialog()
	var on_exit := exit_cells.has(level.world_to_cell(player.global_position))
	extract_t = extract_t + delta if on_exit else 0.0


const REPLAY_CODE := "0719"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var digit := _digit_of(event)
		if digit >= 0:
			secret = (secret + str(digit)).right(REPLAY_CODE.length())
			if secret == REPLAY_CODE:
				secret = ""
				SaveData.prologue_replay = true
				_start_raid("prologue")
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("inventory"):
		if inventory.visible:
			_close_inventory()
		else:
			inventory.open(null)
	elif event.is_action_pressed("interact"):
		if inventory.visible:
			_close_inventory()
		elif dialog_npc != null:
			_advance_dialog()
		else:
			player.interact()
	elif event.is_action_pressed("ui_cancel"):
		if inventory.visible:
			_close_inventory()
		_end_dialog()
	elif event.is_action_pressed("rotate") and inventory.visible:
		inventory.rotate_drag()
	else:
		return
	get_viewport().set_input_as_handled()


## Top-row digits, numpad digits, or whatever the keyboard layout reports as 0-9.
static func _digit_of(ev: InputEventKey) -> int:
	for k in [ev.physical_keycode, ev.keycode]:
		if k >= KEY_0 and k <= KEY_9:
			return k - KEY_0
		if k >= KEY_KP_0 and k <= KEY_KP_9:
			return k - KEY_KP_0
	if ev.unicode >= 48 and ev.unicode <= 57:
		return ev.unicode - 48
	return -1


func _close_inventory() -> void:
	inventory.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_persist()
	_apply_level()


# ---------------------------------------------------------------- interaction

func interact_target(pos: Vector2) -> Dictionary:
	if exit_cells.has(level.world_to_cell(pos)):
		return {"type": "exit", "node": self}
	var best := {}
	var best_d := TALK_RANGE
	for n in get_tree().get_nodes_in_group("npcs"):
		var d := pos.distance_to(n.global_position)
		if d < best_d:
			best = {"type": "npc", "node": n}
			best_d = d
	for box in [stash, donate_box]:
		var d := pos.distance_to(box.global_position)
		if d < best_d:
			best = {"type": "search", "node": box}
			best_d = d
	return best


## Sortie: called by Player.interact on the gate cells.
func interact() -> void:
	_start_raid("ruins")


func _start_raid(which: String) -> void:
	_persist()
	SaveData.next_raid = which
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _leader() -> Npc:
	for n in get_tree().get_nodes_in_group("npcs"):
		if n is Npc and n.role == "leader":
			return n
	return null


func talk_to(npc: Npc) -> void:
	var lines: Array = LINES[npc.role].map(func(l): return [npc.title(), l])
	if npc.counter != null:
		# Traders just say their line and open the counter; the dialogue box would cover it.
		hud.toast("%s: %s" % lines[0])
		inventory.open(npc.counter)
		return
	if npc.role == "leader":
		lines = _leader_lines(npc.title())
	_open_dialog(npc, lines)


## The leader hands out the main quests and takes the items when Toa brings them.
func _leader_lines(who: String) -> Array:
	var lines := []
	var q := Story.quest()
	if q.is_empty():
		lines.append("지금은 맡길 일이 없다. 다음 소식을 기다려.")
	elif not SaveData.quest_given:
		SaveData.quest_given = true
		lines.append_array(q["give"])
		hud.toast("새 임무: %s" % q["title"])
	elif _has_items(q["need"]):
		_take_items(q["need"])
		SaveData.money += q["reward"]
		if q["memory"] != "" and not SaveData.memories.has(q["memory"]):
			SaveData.memories.append(q["memory"])
		lines.append_array(q["done"])
		lines.append("보수 $%d. 받아 둬." % q["reward"])
		hud.toast("임무 완료: %s  +$%d" % [q["title"], q["reward"]])
		SaveData.quest += 1
		SaveData.quest_given = false
	else:
		lines.append("아직이다. %s." % q["objective"])
	var next := SaveData.next_level_at()
	var status := "바파스 레벨 %d." % SaveData.level()
	if next > 0:
		status += " 다음 레벨까지 기부 $%d 남았다." % (next - SaveData.donated)
	lines.append(status)
	_persist()
	return lines.map(func(l): return [who, l])


func _all_items() -> Array:
	return stash.grid.items + player.bag.items + player.pouch.items


func _has_items(need: Dictionary) -> bool:
	for id in need:
		if _all_items().filter(func(i): return i["id"] == id).size() < need[id]:
			return false
	return true


func _take_items(need: Dictionary) -> void:
	for id in need:
		var left: int = need[id]
		for grid in [player.bag, player.pouch, stash.grid]:
			for item in grid.items.duplicate():
				if left > 0 and item["id"] == id:
					grid.remove(item)
					left -= 1


## Recordings found in raids turn into memories as soon as Toa is home.
func _collect_recorders() -> void:
	for grid in [player.bag, player.pouch, stash.grid]:
		for item in grid.items.duplicate():
			if str(item["id"]).begins_with("recorder_"):
				grid.remove(item)
				if not SaveData.memories.has(item["id"]):
					SaveData.memories.append(item["id"])
					hud.toast("기억 조각: %s — 코어 해독기에서 확인" % ItemDB.get_data(item["id"])["name"])
	_persist()


func show_memories() -> void:
	var lines := []
	for id in SaveData.memories:
		var m: Array = Story.MEMORIES[id]
		lines.append([m[0], m[1]])
	if lines.is_empty():
		lines.append(["코어 해독기", "아직 해독된 내용이 없다. 리더의 일을 하거나, 폐허에서 녹음기를 찾아라."])
	for n in get_tree().get_nodes_in_group("npcs"):
		if n is Decoder:
			_open_dialog(n, lines)


func _open_dialog(owner: Node2D, lines: Array) -> void:
	dialog_npc = owner
	dialog_lines = lines
	dialog_i = 0
	hud.show_dialog(lines[0][0], lines[0][1])


func _advance_dialog() -> void:
	dialog_i += 1
	if dialog_i >= dialog_lines.size():
		_end_dialog()
	else:
		hud.show_dialog(dialog_lines[dialog_i][0], dialog_lines[dialog_i][1])


func _end_dialog() -> void:
	dialog_npc = null
	hud.hide_dialog()


# ---------------------------------------------------------------- trading

func _container_of(grid) -> LootContainer:
	if not (grid is InvGrid):
		return null
	for c in [stash, donate_box]:
		if c.grid == grid:
			return c
	for n in get_tree().get_nodes_in_group("npcs"):
		if n is Npc and n.counter != null and n.counter.grid == grid:
			return n.counter
	return null


func buy_price(item: Dictionary) -> int:
	return int(ItemDB.value_of(item) * BUY_MARKUP)


func sell_rate(kind: String, item: Dictionary) -> float:
	var id: String = item["id"]
	match kind:
		"weapon_shop":
			return 0.9 if ItemDB.is_weapon(id) else 0.0
		"doctor":
			return 1.4 if id == "meds" else 0.0
		"junk":
			return 0.5 if ItemDB.is_weapon(id) else 0.85
	return 0.0


## Called by InventoryUI for every move. "ok" places the item, "deny" puts it back,
## "consumed" means the item is gone (sold or donated).
func transfer(item: Dictionary, from, to) -> String:
	var src := _container_of(from)
	var dst := _container_of(to)
	if src == dst and not (to is String):
		return "ok"
	if to is String:
		hud.toast("은신처에서는 버릴 수 없다. 창고에 넣자.")
		return "deny"
	if dst != null and dst.kind != "stash" and Story.is_story_item(item["id"]):
		hud.toast("중요한 물건이다. 넘길 수 없다. 리더에게 가져가자.")
		return "deny"
	if src != null and src.kind == "weapon_shop":
		if dst != null:
			return "deny"
		var price := buy_price(item)
		if SaveData.money < price:
			hud.toast("돈이 부족하다 ($%d 필요)" % price)
			return "deny"
		SaveData.money -= price
		hud.toast("-$%d  %s 구매" % [price, ItemDB.get_data(item["id"])["name"]])
		_restock.call_deferred(src.grid)
		_persist.call_deferred()
		return "ok"
	if dst == null or dst.kind == "stash":
		return "ok"
	if dst.kind == "donate":
		var before := SaveData.level()
		SaveData.donated += ItemDB.value_of(item)
		hud.toast("바파스에 기부 +%d" % ItemDB.value_of(item))
		if SaveData.level() > before:
			hud.toast("바파스 레벨 %d! 가방, 파우치, 창고가 커진다 (창을 닫으면 적용)" % SaveData.level())
		_persist.call_deferred()
		return "consumed"
	var rate := sell_rate(dst.kind, item)
	if rate <= 0.0:
		hud.toast("그건 안 산다.")
		return "deny"
	var gain := int(ItemDB.value_of(item) * rate)
	SaveData.money += gain
	hud.toast("+$%d  %s 판매" % [gain, ItemDB.get_data(item["id"])["name"]])
	_persist.call_deferred()
	return "consumed"


func _restock(grid: InvGrid) -> void:
	for id in SHOP_STOCK:
		if not grid.items.any(func(i): return i["id"] == id):
			grid.auto_add(ItemDB.make(id))


func price_hint(item: Dictionary, grid) -> String:
	var src := _container_of(grid)
	if src != null and src.kind == "weapon_shop":
		return "구매가 $%d" % buy_price(item)
	var counter: LootContainer = inventory.other
	if counter != null and counter.kind in ["weapon_shop", "doctor", "junk"]:
		var rate := sell_rate(counter.kind, item)
		return "판매가 $%d" % int(ItemDB.value_of(item) * rate) if rate > 0.0 else "매입 안 함"
	if counter == donate_box:
		return "기부 +%d" % ItemDB.value_of(item)
	return ""


# ---------------------------------------------------------------- shared with the raid

func carried_weight() -> float:
	var wt := player.bag.total_weight()
	for item in player.slots:
		if item != null:
			wt += ItemDB.weight_of(item)
	return wt


func carried_value() -> int:
	var v := player.bag.total_value()
	for item in player.slots:
		if item != null:
			v += ItemDB.value_of(item)
	return v


func speed_mult() -> float:
	return 1.0


func drop_item(item: Dictionary) -> void:
	if not stash.grid.auto_add(item):
		player.bag.auto_add(item)
