class_name ExtractZone
extends Node2D
## One extraction point. Each kind has its own condition:
## gate: always open. sewer: carried weight limit. car: needs a fuel can in the bag.
## flare: press E to fire a flare; a helicopter arrives after a delay and waits a short while.

const SEWER_MAX_WEIGHT := 12.0
const FLARE_DELAY := 45.0
const FLARE_WINDOW := 40.0
const TITLES := {"gate": "정문 검문소", "sewer": "하수도", "flare": "신호탄 헬기", "car": "차량"}

var kind := "gate"
var cells: Array = []
var title := ""
var flare_state := "idle"  # idle, waiting, ready, gone
var flare_t := 0.0
var light: PointLight2D
var t := 0.0


func setup(zone_kind: String, zone_cells: Array) -> void:
	kind = zone_kind
	cells = zone_cells
	title = TITLES[kind]
	var center := Vector2.ZERO
	for c in cells:
		center += Vector2(c) * Level.CELL + Vector2(Level.CELL, Level.CELL) * 0.5
	position = center / cells.size()


func _ready() -> void:
	add_to_group("extracts")
	light = Lights.make(Color(0.35, 1.0, 0.5), 110.0, 0.7, false)
	add_child(light)


func contains(cell: Vector2i) -> bool:
	return cells.has(cell)


## Empty string when Toa can extract here right now, otherwise the reason shown on screen.
func block_reason(game: Node) -> String:
	match kind:
		"sewer":
			if game.carried_weight() > SEWER_MAX_WEIGHT:
				return "너무 무겁다 (%.0fkg 이하만 통과)" % SEWER_MAX_WEIGHT
		"car":
			if not _find_fuel(game.player.bag):
				return "연료통이 필요하다"
		"flare":
			match flare_state:
				"idle":
					return "E  신호탄 발사 (헬기 호출, 소음 큼)"
				"waiting":
					return "헬기 도착까지 %d초" % ceili(flare_t)
				"gone":
					return "헬기가 떠났다"
	return ""


func is_open(game: Node) -> bool:
	return block_reason(game) == ""


func fire_flare(game: Node) -> void:
	if flare_state != "idle":
		return
	flare_state = "waiting"
	flare_t = FLARE_DELAY
	game.make_noise(global_position, 1400.0, null)
	game.toast("신호탄 발사! 헬기가 %d초 뒤 도착한다" % int(FLARE_DELAY))


## Called on successful extraction; the car burns its fuel.
func consume(game: Node) -> void:
	if kind == "car":
		var fuel = _find_fuel(game.player.bag)
		if fuel != null:
			game.player.bag.remove(fuel)


func _find_fuel(bag: InvGrid):
	for item in bag.items:
		if item["id"] == "fuel":
			return item
	return null


func _process(delta: float) -> void:
	t += delta
	if kind == "flare":
		if flare_state == "waiting":
			flare_t -= delta
			if flare_t <= 0.0:
				flare_state = "ready"
				flare_t = FLARE_WINDOW
				get_tree().get_first_node_in_group("game").toast("헬기 도착! %d초 안에 탑승" % int(FLARE_WINDOW))
		elif flare_state == "ready":
			flare_t -= delta
			if flare_t <= 0.0:
				flare_state = "gone"
	queue_redraw()


func _draw() -> void:
	var col := Color(0.3, 1.0, 0.45)
	if kind == "flare" and flare_state != "ready":
		col = Color(1.0, 0.4, 0.3) if flare_state == "waiting" else Color(0.6, 0.6, 0.6)
	var a := 0.22 + 0.12 * sin(t * 4.0)
	for c in cells:
		var p := Vector2(c) * Level.CELL - position
		draw_rect(Rect2(p, Vector2(Level.CELL, Level.CELL)), Color(col, a))
	if kind == "flare" and flare_state == "waiting":
		draw_circle(Vector2.ZERO, 5.0 + sin(t * 12.0) * 2.0, Color(1.0, 0.3, 0.2))
