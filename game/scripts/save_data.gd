class_name SaveData
extends RefCounted
## Everything that survives between raids: money, stash, what Toa carries, Bapas standing.
## Stored as JSON in user:// (IndexedDB on the web build).

const PATH := "user://scavenge_save.json"
const LEVEL_AT := [0, 800, 2500, 6000, 12000]  # donated value needed for Bapas level 1..5
const BAG_SIZE := [Vector2i(6, 4), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(8, 6)]
const STASH_SIZE := [Vector2i(8, 6), Vector2i(9, 7), Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 9)]
const POUCH_SIZE := [Vector2i(1, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 2), Vector2i(2, 3)]

static var loaded := false
static var enabled := true  # tests switch this off so they never touch the real save
static var money := 300
static var donated := 0
static var raids := 0
static var extracts := 0
static var stash: Array = []
static var bag: Array = []
static var pouch: Array = []
static var slots: Array = [null, null]
static var last_result: Dictionary = {}
# Story progress
static var prologue_done := false
static var intro_pending := false  # show the leader's intro on the next hideout visit
static var quest := 0  # index into Story.QUESTS
static var quest_given := false
static var memories: Array = []  # memory ids unlocked (see Story.MEMORIES)
static var flashbacks_seen: Array = []
static var next_raid := "ruins"  # ruins or prologue
static var prologue_replay := false  # watching the prologue again: nothing is saved (not persisted)


static func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	_reset()
	if not enabled or not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	money = int(data.get("money", money))
	donated = int(data.get("donated", 0))
	raids = int(data.get("raids", 0))
	extracts = int(data.get("extracts", 0))
	stash = _items_in(data.get("stash", []))
	bag = _items_in(data.get("bag", []))
	pouch = _items_in(data.get("pouch", []))
	prologue_done = bool(data.get("prologue_done", false))
	intro_pending = bool(data.get("intro_pending", false))
	quest = int(data.get("quest", 0))
	quest_given = bool(data.get("quest_given", false))
	memories = Array(data.get("memories", []))
	flashbacks_seen = Array(data.get("flashbacks_seen", []))
	var s: Array = data.get("slots", [null, null])
	slots = [_item_in(s[0]) if s.size() > 0 else null, _item_in(s[1]) if s.size() > 1 else null]


static func _reset() -> void:
	money = 300
	donated = 0
	raids = 0
	extracts = 0
	stash = [ItemDB.make("pistol"), ItemDB.make("knife")]
	bag = []
	pouch = []
	slots = [null, null]
	last_result = {}
	prologue_done = false
	intro_pending = false
	quest = 0
	quest_given = false
	memories = []
	flashbacks_seen = []
	next_raid = "ruins"


static func save() -> void:
	if not enabled:
		return
	var data := {"money": money, "donated": donated, "raids": raids, "extracts": extracts,
		"stash": stash, "bag": bag, "pouch": pouch, "slots": slots,
		"prologue_done": prologue_done, "intro_pending": intro_pending, "quest": quest,
		"quest_given": quest_given, "memories": memories, "flashbacks_seen": flashbacks_seen}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


static func wipe() -> void:
	_reset()
	save()


static func _item_in(d):
	if typeof(d) != TYPE_DICTIONARY or not ItemDB.DATA.has(str(d.get("id", ""))):
		return null
	return {"id": str(d["id"]), "rot": bool(d.get("rot", false)), "x": int(d.get("x", 0)),
		"y": int(d.get("y", 0)), "ammo": int(d.get("ammo", 0))}


static func _items_in(arr) -> Array:
	var out := []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for d in arr:
		var item = _item_in(d)
		if item != null:
			out.append(item)
	return out


# ---------------------------------------------------------------- Bapas standing

static func level() -> int:
	var lv := 1
	for i in LEVEL_AT.size():
		if donated >= LEVEL_AT[i]:
			lv = i + 1
	return lv


static func next_level_at() -> int:
	var lv := level()
	return LEVEL_AT[lv] if lv < LEVEL_AT.size() else -1


static func _size(table: Array) -> Vector2i:
	return table[level() - 1]


## A grid of the current size holding the saved items; items that no longer fit are returned in `overflow`.
static func make_grid(kind: String, items: Array, overflow: Array) -> InvGrid:
	var s: Vector2i = _size({"bag": BAG_SIZE, "stash": STASH_SIZE, "pouch": POUCH_SIZE}[kind])
	var g := InvGrid.new(s.x, s.y)
	for item in items:
		var copy: Dictionary = item.duplicate()
		if not g.add_at(copy, copy["x"], copy["y"], copy["rot"]) and not g.auto_add(copy):
			overflow.append(copy)
	return g


static func store_loadout(bag_grid: InvGrid, pouch_grid: InvGrid, slot_items: Array) -> void:
	bag = bag_grid.items.duplicate(true)
	pouch = pouch_grid.items.duplicate(true)
	slots = [slot_items[0].duplicate() if slot_items[0] != null else null,
		slot_items[1].duplicate() if slot_items[1] != null else null]


## End of the prologue: Toa wakes up with nothing but the core in the safe pouch.
static func finish_prologue() -> void:
	prologue_done = true
	intro_pending = true
	bag = []
	slots = [null, null]
	pouch = [ItemDB.make("core")]
	next_raid = "ruins"
	save()


## End of a raid. Extracting keeps everything; dying keeps only the safe pouch.
static func record_raid(extracted: bool, bag_grid: InvGrid, pouch_grid: InvGrid, slot_items: Array, value: int) -> void:
	raids += 1
	if extracted:
		extracts += 1
		store_loadout(bag_grid, pouch_grid, slot_items)
	else:
		bag = []
		slots = [null, null]
		pouch = pouch_grid.items.duplicate(true)
	last_result = {"extracted": extracted, "value": value}
	save()
