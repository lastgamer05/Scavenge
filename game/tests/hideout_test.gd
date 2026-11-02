extends SceneTree
## Headless hideout checks: trading, donating, Bapas levels, loadout carried into and out of a raid.

var frame := 0
var hideout: Node
var failures := 0


func _initialize() -> void:
	SaveData.enabled = false
	SaveData.loaded = false
	hideout = load("res://scenes/hideout.tscn").instantiate()
	root.add_child(hideout)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1


func _npc(role: String) -> Npc:
	for n in get_nodes_in_group("npcs"):
		if n.role == role:
			return n
	return null


func _process(_delta: float) -> bool:
	frame += 1
	if frame != 5:
		return false
	var h = hideout
	var p: Player = h.player
	_check(get_nodes_in_group("npcs").size() == 5, "five Bapas NPCs")
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

	print("hideout finished: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return false
