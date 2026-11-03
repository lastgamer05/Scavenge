class_name Zones
extends RefCounted
## Raid areas in order of difficulty. Each opens after one successful extraction from the one before.
##   skill: enemy reaction and aim speed (1.0 = the original ruins)
##   centra: share of the map's enemies that are Centra soldiers instead of scavengers
##   reinforce_after: seconds into the raid before Centra patrols start arriving

const LIST := [
	{"id": "outskirts", "name": "외곽 마을", "level": "쉬움", "map": "res://data/maps/outskirts.txt",
		"desc": "약탈자 몇 명이 어슬렁거리는 버려진 마을. 방망이 하나로 충분하다.",
		"time": 600.0, "reinforce_after": 99999.0, "skill": 0.6, "centra": 0.0},
	{"id": "ruins", "name": "폐허 구역", "level": "보통", "map": "res://data/maps/ruins.txt",
		"desc": "무장한 약탈자와 용병이 진을 친 시가지. 10분이 넘으면 센트라가 들어온다.",
		"time": 900.0, "reinforce_after": 600.0, "skill": 1.0, "centra": 0.0},
	{"id": "checkpoint", "name": "센트라 검문소", "level": "어려움", "map": "res://data/maps/checkpoint.txt",
		"desc": "센트라 정규군의 보급 거점. 금고는 두둑하지만 5분 만에 순찰대가 몰려온다.",
		"time": 720.0, "reinforce_after": 300.0, "skill": 1.3, "centra": 0.7},
]


static func get_zone(id: String) -> Dictionary:
	for z in LIST:
		if z["id"] == id:
			return z
	return LIST[0]


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return -1


## The first zone is always open; the rest need an extraction from the zone before.
static func is_unlocked(id: String) -> bool:
	var i := index_of(id)
	return i == 0 or (i > 0 and int(SaveData.zone_extracts.get(LIST[i - 1]["id"], 0)) > 0)


static func unlocked() -> Array:
	return LIST.filter(func(z): return is_unlocked(z["id"]))
