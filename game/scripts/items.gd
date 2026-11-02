class_name ItemDB
extends RefCounted
## Item table and loot tables. Weapons share ids with WeaponDB so they can live in the bag too.

const VALUABLE := Color(0.8, 0.65, 0.25)
const TECH := Color(0.3, 0.55, 0.8)
const MEDICAL := Color(0.75, 0.3, 0.35)
const SUPPLY := Color(0.5, 0.42, 0.3)
const WEAPON := Color(0.45, 0.47, 0.5)

const DATA := {
	"cash": {"name": "현금 뭉치", "size": Vector2i(1, 1), "value": 150, "weight": 0.1, "color": VALUABLE},
	"watch": {"name": "금시계", "size": Vector2i(1, 1), "value": 300, "weight": 0.2, "color": VALUABLE},
	"goldbar": {"name": "금괴", "size": Vector2i(1, 1), "value": 800, "weight": 2.0, "color": VALUABLE},
	"docs": {"name": "기밀 문서", "size": Vector2i(1, 1), "value": 400, "weight": 0.1, "color": VALUABLE},
	"gpu": {"name": "그래픽카드", "size": Vector2i(2, 1), "value": 600, "weight": 1.0, "color": TECH},
	"laptop": {"name": "노트북", "size": Vector2i(2, 2), "value": 500, "weight": 2.5, "color": TECH},
	"radio": {"name": "무전기", "size": Vector2i(1, 2), "value": 220, "weight": 0.8, "color": TECH},
	"meds": {"name": "의약품", "size": Vector2i(1, 2), "value": 250, "weight": 0.5, "color": MEDICAL},
	"cans": {"name": "통조림", "size": Vector2i(1, 1), "value": 40, "weight": 0.4, "color": SUPPLY},
	"parts": {"name": "기계 부품", "size": Vector2i(2, 1), "value": 120, "weight": 1.5, "color": SUPPLY},
	"fuel": {"name": "연료통", "size": Vector2i(2, 2), "value": 200, "weight": 5.0, "color": SUPPLY},
	"ammo_box": {"name": "탄약 상자", "size": Vector2i(2, 1), "value": 180, "weight": 2.0, "color": SUPPLY},
	"pistol": {"name": "권총", "size": Vector2i(2, 1), "value": 200, "weight": 1.0, "color": WEAPON},
	"silenced": {"name": "소음기 권총", "size": Vector2i(2, 1), "value": 350, "weight": 1.2, "color": WEAPON},
	"smg": {"name": "기관단총", "size": Vector2i(3, 2), "value": 500, "weight": 3.0, "color": WEAPON},
	"shotgun": {"name": "산탄총", "size": Vector2i(4, 1), "value": 450, "weight": 3.5, "color": WEAPON},
	"rifle": {"name": "소총", "size": Vector2i(4, 1), "value": 700, "weight": 4.0, "color": WEAPON},
	"bat": {"name": "야구방망이", "size": Vector2i(3, 1), "value": 60, "weight": 1.5, "color": WEAPON},
	"knife": {"name": "칼", "size": Vector2i(1, 1), "value": 80, "weight": 0.3, "color": WEAPON},
}

const LOOT := {
	"crate": {"title": "나무 상자", "size": Vector2i(4, 4), "rolls": Vector2i(2, 4),
		"pool": ["cans", "cans", "parts", "fuel", "cash", "radio", "ammo_box"]},
	"locker": {"title": "사물함", "size": Vector2i(4, 5), "rolls": Vector2i(2, 4),
		"pool": ["meds", "meds", "gpu", "laptop", "radio", "docs", "watch"]},
	"safe": {"title": "금고", "size": Vector2i(3, 3), "rolls": Vector2i(2, 3),
		"pool": ["goldbar", "goldbar", "watch", "cash", "cash", "docs"]},
	"corpse": {"title": "시체", "size": Vector2i(4, 3), "rolls": Vector2i(0, 2),
		"pool": ["cash", "cans", "meds", "watch", "ammo_box"]},
	"pile": {"title": "버린 물건", "size": Vector2i(6, 4), "rolls": Vector2i(0, 0), "pool": []},
}


## A new item instance. Weapons carry their remaining ammo.
static func make(id: String, ammo: int = -1) -> Dictionary:
	if ammo < 0:
		ammo = WeaponDB.get_data(id).get("ammo", 0) if is_weapon(id) else 0
	return {"id": id, "rot": false, "x": 0, "y": 0, "ammo": ammo}


static func get_data(id: String) -> Dictionary:
	return DATA[id]


static func is_weapon(id: String) -> bool:
	return WeaponDB.DATA.has(id) and id != "fists"


static func size_of(item: Dictionary, rot: bool) -> Vector2i:
	var s: Vector2i = DATA[item["id"]]["size"]
	return Vector2i(s.y, s.x) if rot else s


static func value_of(item: Dictionary) -> int:
	return DATA[item["id"]]["value"]


static func weight_of(item: Dictionary) -> float:
	return DATA[item["id"]]["weight"]


static func fill(grid: InvGrid, kind: String) -> void:
	var table: Dictionary = LOOT[kind]
	var rolls: Vector2i = table["rolls"]
	var pool: Array = table["pool"]
	for i in randi_range(rolls.x, rolls.y):
		grid.auto_add(make(pool.pick_random()))
