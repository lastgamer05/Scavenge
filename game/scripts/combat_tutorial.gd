class_name CombatTutorial
extends Node
## The first raid's combat lesson, run on the outskirts before the real raid starts.
## Targets are passive scavengers (they never fight back) placed near Toa one at a time:
## move, take a bat in hand, club one from behind, pick up a one-bullet pistol and shoot,
## then throw a gun to knock one down and execute it. The raid clock waits until it is done.

const STEPS := [
	"WASD로 움직이고, 마우스로 주변을 둘러보자",
	"방망이를 손에 들자",
	"약탈자 등 뒤로 다가가 좌클릭 — 방망이는 조용하고 한 방이다",
	"권총을 주워 손에 들자 (E). 재장전은 없다 — 남은 탄이 전부다",
	"좌클릭으로 쏴라. 총소리는 멀리까지 퍼진다",
	"우클릭으로 총을 던져라. 맞으면 쓰러진다 — 쓰러진 적에게 다가가 E로 처형",
	"훈련 끝. 건물과 상자를 뒤져 물자를 챙기고, 탈출 지점까지 살아서 가자",
]
const DONE_SHOW := 7.0

var game: Node
var step := 0
var start := Vector2.ZERO
var target: Enemy = null
var arrow: PointerArrow
var done_t := 0.0


func setup(g: Node) -> void:
	game = g
	start = game.player.global_position
	arrow = PointerArrow.new()
	arrow.visible = false
	game.fx_layer.add_child(arrow)
	_enter(0)


func running() -> bool:
	return step < STEPS.size() - 1


func _process(delta: float) -> void:
	var p: Player = game.player
	if not p.alive:
		game.hud.tutorial_label.text = ""
		arrow.visible = false
		return
	var held := p.current_id()
	var melee_in_hand: bool = held != "fists" and WeaponDB.get_data(held)["melee"]
	match step:
		0:
			if p.global_position.distance_to(start) > 120.0:
				_enter(1)
		1:
			if melee_in_hand:
				_enter(2)
		2, 4, 5:
			if target == null or target.is_dead():
				_enter(step + 1)
			elif step == 4 and WeaponDB.is_gun(held) and p.slots[p.current]["ammo"] <= 0:
				_enter(5)  # missed: the empty gun is the next lesson anyway
		3:
			if held == "pistol":
				_enter(4)
		6:
			done_t -= delta
			if done_t <= 0.0:
				game.hud.tutorial_label.text = ""
				set_process(false)
				return
	game.hud.tutorial_label.text = "▶ " + _hint()


func _hint() -> String:
	var p: Player = game.player
	if step == 1 and not p.slots.any(func(w): return w != null and WeaponDB.get_data(w["id"])["melee"]):
		return "바닥의 방망이를 줍자 — 가까이 가서 E"
	if step == 1:
		return "Q(또는 1/2)로 방망이를 손에 들자"
	if step == 3 and p.slots.any(func(w): return w != null and w["id"] == "pistol"):
		return "Q(또는 1/2)로 권총을 손에 들자"
	return STEPS[step]


func _enter(s: int) -> void:
	step = s
	arrow.target = null
	arrow.visible = false
	var p: Player = game.player
	match step:
		1:
			if not p.slots.any(func(w): return w != null and WeaponDB.get_data(w["id"])["melee"]):
				_point_at_pickup("bat", 0)
		2:
			target = _spawn_target()
		3:
			_point_at_pickup("pistol", 1)
		4:
			target = _spawn_target()
		5:
			if target == null or target.is_dead():
				target = _spawn_target()
			if not WeaponDB.is_gun(p.current_id()):
				game.spawn_pickup("pistol", 0, _spot(2.0, 3.0), Vector2.ZERO, false)
		6:
			target = null
			done_t = DONE_SHOW
			SaveData.combat_tutorial = true
			SaveData.save()


func _point_at_pickup(id: String, ammo: int) -> void:
	game.spawn_pickup(id, ammo, _spot(2.0, 4.0), Vector2.ZERO, false)
	arrow.target = game.nearest_pickup(game.player.global_position, 400.0)
	arrow.visible = arrow.target != null


## A scavenger who stands still facing away from Toa and never fights back.
func _spawn_target() -> Enemy:
	var e := Enemy.new()
	e.game = game
	e.level = game.level
	e.weapon_id = "fists"
	e.passive = true
	e.skill = 0.6
	e.position = _spot(4.0, 7.0)
	game.entities.add_child(e)
	e.facing = (e.global_position - game.player.global_position).angle()
	game.total_enemies += 1
	arrow.target = e
	arrow.visible = true
	return e


## A floor spot min..max cells from Toa that Toa can see.
func _spot(min_cells: float, max_cells: float) -> Vector2:
	var p: Vector2 = game.player.global_position
	var lv: Level = game.level
	for i in 60:
		var c: Vector2 = p + Vector2.from_angle(randf() * TAU) * randf_range(min_cells, max_cells) * Level.CELL
		var cell := lv.world_to_cell(c)
		if not lv.is_wall(cell) and not lv.is_extract(cell) and game.has_los(p, c):
			return lv.cell_to_world(cell)
	return lv.random_floor_near(p, int(max_cells))
