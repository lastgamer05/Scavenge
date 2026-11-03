extends SceneTree
## Headless hideout checks: trading, donating, Bapas levels, loadout carried into and out of a raid.

var frame := 0
var hideout: Node
var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	SaveData.loaded = false
	SaveData.ensure_loaded()
	SaveData.prologue_done = true
	hideout = load("res://scenes/hideout.tscn").instantiate()
	root.add_child(hideout)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1


func _npc(role: String) -> Npc:
	for n in get_nodes_in_group("npcs"):
		if n is Npc and n.role == role:
			return n
	return null


func _test_tutorial(h, p: Player) -> void:
	SaveData.tutorial = 0
	h._end_dialog()
	h._tick_tutorial()
	_check(h.hud.tutorial_label.text != "" and h.tutorial_arrow.visible, "first visit shows the tutorial hint and arrow")
	var dealer: Npc = _npc("weapons")
	h.inventory.open(dealer.counter)
	h._tick_tutorial()
	_check(SaveData.tutorial == 1, "opening Gor's counter advances the tutorial")
	p.slots[0] = ItemDB.make("bat")
	h._close_inventory()
	h._tick_tutorial()
	_check(SaveData.tutorial == 2 and h.dialog_npc == dealer, "a bat in hand: Gor explains the basics")
	h._end_dialog()
	h._tick_tutorial()
	_check(h.tutorial_arrow.position == h.level.cell_to_world(h.exit_cells[0]), "then the arrow points at the tunnel")
	SaveData.tutorial = 99
	h._tick_tutorial()
	_check(h.hud.tutorial_label.text == "" and not h.tutorial_arrow.visible, "finished tutorial stays hidden")


func _process(_delta: float) -> bool:
	frame += 1
	if frame != 5:
		return false
	var h = hideout
	var p: Player = h.player
	_check(get_nodes_in_group("npcs").filter(func(n): return n is Npc).size() == 5, "five Bapas NPCs")
	_check(h.stash.grid.items.size() == 2, "new save starts with a pistol and knife in the stash")
	_check(SaveData.money == 300, "new save starts with $300")

	var shop: LootContainer = _npc("weapons").counter
	var pistol = shop.grid.items.filter(func(i): return i["id"] == "pistol")[0]
	_check(h.transfer(pistol, shop.grid, p.bag) == "ok" and SaveData.money == 0, "buying a pistol costs $300")
	shop.grid.remove(pistol)
	p.bag.auto_add(pistol)
	h._restock(shop.grid)
	_check(shop.grid.items.any(func(i): return i["id"] == "pistol"), "shop restocks")
	var rifle = shop.grid.items.filter(func(i): return i["id"] == "rifle")[0]
	_check(h.transfer(rifle, shop.grid, p.bag) == "deny", "cannot buy without money")

	var meds := ItemDB.make("meds")
	_check(h.transfer(meds, p.bag, _npc("doctor").counter.grid) == "consumed" and SaveData.money == 350, "doctor buys meds at 140%")
	_check(h.transfer(ItemDB.make("cans"), p.bag, _npc("doctor").counter.grid) == "deny", "doctor refuses non-medical items")
	_check(h.transfer(ItemDB.make("gpu"), p.bag, _npc("junk").counter.grid) == "consumed" and SaveData.money == 860, "junk dealer buys at 85%")
	_check(h.transfer(ItemDB.make("cash"), p.bag, "drop") == "deny", "no dropping in the hideout")

	_check(SaveData.level() == 1, "Bapas starts at level 1")
	h.transfer(ItemDB.make("goldbar"), p.bag, h.donate_box.grid)
	_check(SaveData.level() == 2 and SaveData.donated == 800, "donating $800 reaches level 2")
	h._close_inventory()
	_check(p.bag.h == 5, "level 2 grows the bag to 6x5")
	_check(p.bag.items.size() == 1, "bag contents survive the resize")

	SaveData.store_loadout(p.bag, p.pouch, p.slots)
	var raid_bag := SaveData.make_grid("bag", SaveData.bag, [])
	var pouch := SaveData.make_grid("pouch", [ItemDB.make("watch")], [])
	SaveData.record_raid(false, raid_bag, pouch, [ItemDB.make("smg"), null], 900)
	_check(SaveData.bag.is_empty() and SaveData.slots == [null, null], "death empties bag and slots")
	_check(SaveData.pouch.size() == 1, "safe pouch survives death")
	SaveData.record_raid(true, raid_bag, pouch, [ItemDB.make("smg"), null], 900)
	_check(SaveData.bag.size() == 1 and SaveData.slots[0]["id"] == "smg", "extraction keeps the loadout")
	_check(SaveData.raids == 2 and SaveData.extracts == 1, "raid counters")

	_test_tutorial(h, p)
	_test_story(h, p)
	_test_sortie_menu(h)
	_test_reset_code(h)
	_test_replay_code(h)
	print("hideout finished: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return false


func _test_story(h, p: Player) -> void:
	SaveData.quest = 0
	SaveData.quest_given = false
	var leader: Npc = _npc("leader")
	leader.interact()
	_check(SaveData.quest_given, "leader gives the first quest")
	_check(Story.objective_text().contains("의약품"), "objective shows on the HUD")
	h._end_dialog()
	leader.interact()
	_check(SaveData.quest == 0, "quest not done without the items")
	h._end_dialog()
	p.bag.items.clear()
	p.bag.auto_add(ItemDB.make("meds"))
	h.stash.grid.auto_add(ItemDB.make("meds"))
	var money := SaveData.money
	leader.interact()
	_check(SaveData.quest == 1 and SaveData.money == money + 400, "delivering two meds completes quest 1 (+$400)")
	_check(not h._all_items().any(func(i): return i["id"] == "meds"), "leader takes the meds from bag and stash")
	h._end_dialog()
	_check(h.transfer(ItemDB.make("dogtag"), p.bag, _npc("junk").counter.grid) == "deny", "story items cannot be sold")
	p.bag.auto_add(ItemDB.make("recorder_2"))
	h._collect_recorders()
	_check(SaveData.memories.has("recorder_2") and not p.bag.items.any(func(i): return i["id"] == "recorder_2"), "recorders become memories at home")
	h.show_memories()
	_check(h.dialog_npc != null and h.dialog_lines.size() == SaveData.memories.size(), "decoder lists unlocked memories")


func _test_replay_code(h) -> void:
	var done_before := SaveData.prologue_done
	for d in [5, 0, 7, 1, 9]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_0 + d
		ev.pressed = true
		h._unhandled_input(ev)
	_check(SaveData.prologue_replay and SaveData.next_raid == "prologue", "typing 0719 in the hideout replays the prologue")
	_check(SaveData.prologue_done == done_before, "replay does not reset story progress")


func _test_sortie_menu(h) -> void:
	SaveData.zone_extracts = {"outskirts": 1}
	h.interact()
	_check(h.picking and h.hud.dialog_text.text.contains("폐허 구역") and h.hud.dialog_text.text.contains("[잠김] 센트라 검문소"),
		"two zones open: the tunnel asks where to go and shows what is still locked")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_3
	ev.pressed = true
	h._unhandled_input(ev)
	_check(h.picking and SaveData.next_raid != "checkpoint", "a locked zone cannot be picked")
	ev = InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	h._picker_input(ev)
	_check(not h.picking and not h.hud.dialog_panel.visible, "Esc closes the sortie menu")


func _test_reset_code(h) -> void:
	var prompt: ResetPrompt = h.get_children().filter(func(n): return n is ResetPrompt)[0]
	for d in [0, 0, 0, 0]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_0 + d
		ev.pressed = true
		prompt._unhandled_input(ev)
	_check(prompt.is_open(), "typing 0000 asks before wiping the save")
	var money := SaveData.money
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	prompt._unhandled_input(esc)
	_check(not prompt.is_open() and SaveData.money == money, "Esc keeps the save")
	SaveData.money = 999
	SaveData.zone_extracts = {"outskirts": 2}
	SaveData.wipe()
	_check(SaveData.money == 300 and SaveData.zone_extracts.is_empty() and not SaveData.prologue_done,
		"wiping starts over from the prologue")
	SaveData.prologue_done = true
