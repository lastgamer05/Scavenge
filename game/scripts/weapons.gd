class_name WeaponDB
extends RefCounted
## Static weapon table. Guns have no reload: when ammo runs out, throw them.

const DATA := {
	"pistol": {"name": "권총", "melee": false, "auto": false, "cooldown": 0.2, "ammo": 12,
		"pellets": 1, "spread": 3.0, "noise": 520.0, "length": 12.0},
	"silenced": {"name": "소음기 권총", "melee": false, "auto": false, "cooldown": 0.28, "ammo": 10,
		"pellets": 1, "spread": 2.0, "noise": 90.0, "length": 18.0},
	"smg": {"name": "기관단총", "melee": false, "auto": true, "cooldown": 0.075, "ammo": 30,
		"pellets": 1, "spread": 8.0, "noise": 600.0, "length": 16.0},
	"shotgun": {"name": "산탄총", "melee": false, "auto": false, "cooldown": 0.65, "ammo": 6,
		"pellets": 7, "spread": 16.0, "noise": 760.0, "length": 22.0},
	"rifle": {"name": "소총", "melee": false, "auto": true, "cooldown": 0.11, "ammo": 24,
		"pellets": 1, "spread": 4.0, "noise": 880.0, "length": 26.0},
	"bat": {"name": "야구방망이", "melee": true, "lethal": true, "cooldown": 0.38, "range": 46.0,
		"arc": 90.0, "noise": 70.0, "length": 20.0},
	"knife": {"name": "칼", "melee": true, "lethal": true, "cooldown": 0.25, "range": 36.0,
		"arc": 70.0, "noise": 30.0, "length": 10.0},
	"fists": {"name": "맨손", "melee": true, "lethal": false, "cooldown": 0.3, "range": 32.0,
		"arc": 80.0, "noise": 40.0, "length": 0.0},
}


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["fists"])


static func is_gun(id: String) -> bool:
	return DATA.has(id) and not DATA[id]["melee"]


static func color_of(id: String) -> Color:
	if id == "silenced":
		return Color(0.55, 0.75, 0.95)
	if is_gun(id):
		return Color(0.85, 0.85, 0.8)
	return Color(0.8, 0.6, 0.35)
