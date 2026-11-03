class_name Story
extends RefCounted
## Act 1 story content: prologue script, main quests, memory fragments and raid-side setup.

# ---------------------------------------------------------------- prologue

const PROLOGUE_BRIEF := [
	["팀장 레온", "작전명 '회수'. 붕괴 진원지 시설, 지하 금고에 봉인된 케이스 하나. 그거면 끝이다."],
	["팀장 레온", "토아, 네가 앞장서. 회사가 굳이 너를 지목했더군. 이유는 묻지 마라."],
	["대원 카스", "안에 약탈자들이 진을 쳤답니다. 정리하면서 들어가죠."],
]
const PROLOGUE_DOOR := ["토아", "…0-7-1-9. 처음 보는 문인데, 손이 먼저 번호를 누른다."]
const PROLOGUE_CASE := ["팀장 레온", "케이스 확보. 옥상 헬기장으로 가. 계단은 내가 지키지."]
# Rooftop cutscene: [seconds from start, speaker, line]
const PROLOGUE_ROOF := [
	[0.6, "대원 카스", "헬기 소리가… 안 들리는데요."],
	[3.2, "대원 미로", "예정 시각은 지났어. 팀장님?"],
	[5.6, "토아", "…레온?"],
	[7.6, "팀장 레온", "케이스는 거기 두고 가라, 토아."],
	[10.4, "팀장 레온", "회사 명령이다. 처음부터 널 쓰려고 고른 거였어."],
	[13.4, "토아", "레온!"],
	[16.2, "대원 미로", "저 빨간 점들… 표적 지시기다! 엎드려!"],
]
const PROLOGUE_AFTER := [
	"눈을 떴을 때, 팀은 전부 죽어 있었다.",
	"케이스는 부서졌고, 안에 있던 데이터 코어만 안전 파우치 속에 남아 있었다.",
	"회사는 팀 전원을 '작전 중 사망'으로 보고했다.",
	"기록상, 토아는 죽은 사람이 되었다.",
]

# ---------------------------------------------------------------- hideout intro

const INTRO := [
	["리더 하엘", "깨어났군. 진원지 근처에서 널 끌고 온 게 우리 바파스다."],
	["리더 하엘", "넌 기록상 죽은 사람이다. 센트라도, 네 회사도 널 찾지 않아. 코어만 빼고."],
	["리더 하엘", "그 코어를 해독하고 싶다. 넌 널 버린 놈들한테 갚아 주고 싶겠지. 손을 잡자."],
	["리더 하엘", "우선 일부터 해. 폐허에 나가 물자를 가져와. 그게 여기 규칙이다."],
]

# ---------------------------------------------------------------- quests

## Each quest: title, objective shown on the HUD, lines when given, items to hand over,
## reward money, lines when completed, and the memory unlocked on completion.
const QUESTS := [
	{
		"title": "첫 번째 일감",
		"objective": "의약품 2개를 리더에게 가져가기",
		"give": ["바파스에는 다친 사람이 많다. 폐허 사물함에 약이 남아 있을 거야. 두 개만 구해 와."],
		"need": {"meds": 2},
		"reward": 400,
		"done": ["좋아. 말만 앞서는 용병은 아니군. 이제 진짜 일 얘기를 하지."],
		"memory": "",
	},
	{
		"title": "해독기 부품",
		"objective": "공장에서 해독 회로를 찾아 리더에게 가져가기",
		"give": ["코어를 열려면 해독 회로가 필요하다. 동쪽 공장 어딘가에 센트라가 남긴 게 있을 거다."],
		"need": {"decoder_part": 1},
		"reward": 600,
		"done": ["됐다. 해독기에 꽂아 보지. …첫 번째 파일이 열렸다. 해독기에서 직접 확인해."],
		"memory": "decode_1",
	},
	{
		"title": "센트라의 기록",
		"objective": "관공서 금고에서 센트라 작전 기록을 회수하기",
		"give": ["코어 파일이 '회수 대상 07'이라는 걸 가리킨다. 관공서 금고에 센트라 작전 기록이 있다는 정보가 있어."],
		"need": {"centra_log": 1},
		"reward": 800,
		"done": ["…이 기록, 붕괴 당일 생존자 이야기다. 토아. 해독기를 봐라."],
		"memory": "decode_2",
	},
	{
		"title": "옛 팀장",
		"objective": "남쪽 창고의 레온을 쓰러뜨리고 인식표를 가져오기",
		"give": ["정보원이 봤다. 네 팀장, 레온. 살아 있다. 센트라 군복을 입고 남쪽 창고에 나타났다더군.",
			"그놈 인식표를 가져와. 폭격 명령이 어디서 왔는지 알 수 있을 거다."],
		"need": {"dogtag": 1},
		"reward": 1500,
		"done": ["07. 그게 너였군. 붕괴 당일 그 시설의 경비병, 유일한 생존자.",
			"이제 우리가 쫓는 건 센트라의 비밀만이 아니다. 네 과거다.",
			"— 1막 끝. 2막은 다음 업데이트에서 이어집니다 —"],
		"memory": "decode_3",
	},
]

# ---------------------------------------------------------------- memories

const MEMORIES := {
	"decode_1": ["코어 해독 1단계", "파일명 '회수 대상 07'. 첨부된 사진 속 경비병의 얼굴이 이상하게 낯익다."],
	"decode_2": ["코어 해독 2단계", "센트라 작전 기록: '붕괴 당일 시설 생존자 1명. 기억 처리 후 신원 변경. 출입 권한 보존을 위해 생체 열쇠로 관리.'"],
	"decode_3": ["코어 해독 3단계", "레온의 인식표 뒷면에 새겨진 좌표와 문구: '07 회수 후 폐기.' 그는 처음부터 알고 있었다."],
	"recorder_1": ["녹음기 #1", "\"경보가 울린 지 3분. 지하 연구동에서 증기가 새고 있다. 07번, 출입문을 봉쇄해!\""],
	"recorder_2": ["녹음기 #2", "\"위에서 철수 명령이 내려왔다. 연구원들은 두고 가라고. 이게 말이 되나?\""],
	"recorder_3": ["녹음기 #3", "\"도시 전체가 대피 중이다. 센트라 차량만 반대 방향으로 들어간다. 뭘 실어 가는 거지?\""],
	"recorder_4": ["녹음기 #4", "\"07번 경비병 생체 반응 확인. 생존. 위원회에 보고 바람. 처리 방침 대기.\""],
}

const FLASHBACKS := {
	"office": "…이 복도. 쇠 냄새. 누군가 내 이름을 불렀다. 토아가 아닌, 다른 이름으로.",
	"factory": "…증기 소리, 붉은 경보등. '07번, 문을 닫아!' 내 손이 레버를 당기고 있었다.",
}
const FLASHBACK_CELLS := {"office": Vector2i(53, 30), "factory": Vector2i(100, 30)}

# Raid-side placement on ruins.txt
const QUEST_ITEM_SPOT := {"decoder_part": Vector2i(100, 42), "centra_log": Vector2i(53, 40)}
const BOSS_SPOT := Vector2i(95, 62)
const RECORDER_SPOTS := {"recorder_1": Vector2i(10, 6), "recorder_2": Vector2i(44, 10),
	"recorder_3": Vector2i(20, 70), "recorder_4": Vector2i(64, 42)}


static func quest() -> Dictionary:
	return QUESTS[SaveData.quest] if SaveData.quest < QUESTS.size() else {}


static func objective_text() -> String:
	var q := quest()
	if q.is_empty() or not SaveData.quest_given:
		return ""
	return "%s: %s" % [q["title"], q["objective"]]


## Places this quest's item, the boss, uncollected recorders and flashback triggers in a raid.
static func raid_setup(game: Node) -> void:
	var q := quest()
	if SaveData.quest_given and not q.is_empty():
		for id in q["need"]:
			if QUEST_ITEM_SPOT.has(id):
				var box: LootContainer = _container_near(game, game.level.cell_to_world(QUEST_ITEM_SPOT[id]))
				if box != null and box.grid.auto_add(ItemDB.make(id)):
					game.add_objective(box.global_position, q["title"])
		if q["need"].has("dogtag"):
			game.spawn_boss(game.level.cell_to_world(BOSS_SPOT))
	for id in RECORDER_SPOTS:
		if not SaveData.memories.has(id):
			var cache := LootContainer.new()
			cache.setup("cache", false)
			cache.grid.auto_add(ItemDB.make(id))
			cache.position = _floor_near(game.level, RECORDER_SPOTS[id])
			game.entities.add_child(cache)


static func _container_near(game: Node, pos: Vector2) -> LootContainer:
	var best: LootContainer = null
	var best_d := INF
	for c in game.get_tree().get_nodes_in_group("containers"):
		if c.kind in ["crate", "locker", "safe"] and c.global_position.distance_to(pos) < best_d:
			best = c
			best_d = c.global_position.distance_to(pos)
	return best


static func _floor_near(level: Level, cell: Vector2i) -> Vector2:
	for r in range(0, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if not level.is_wall(c) and not level.is_extract(c):
					return level.cell_to_world(c)
	return level.cell_to_world(cell)


## Story items are delivered in the hideout; recorders become memories as soon as Toa is home.
static func is_story_item(id: String) -> bool:
	return ItemDB.DATA.has(id) and ItemDB.DATA[id].get("story", false)
