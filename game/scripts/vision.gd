class_name Vision
extends Node2D
## Toa's line of sight. Walls and closed doors cast shade away from her, and enemies she cannot
## see are hidden: they leave a fading ghost where they were last seen, and their footsteps and
## gunshots reach the HUD as direction pings instead.

const REACH := 2400.0  # how far shadows are extruded past a wall
const CULL := 1100.0  # walls and enemies further than this from Toa are skipped
const SENSE := 50.0  # enemies this close are felt through walls, faintly
const GHOST_TIME := 1.5
const STEP_RANGE := 230.0  # hidden enemies this close are heard walking
const STEP_EVERY := 0.45
const SHADE_ALPHA := 0.72

var game: Node
var rects: Array[Rect2] = []
var shade: CanvasGroup
var ghosts := {}  # Enemy -> [Vector2 last seen, float time left]
var steps := {}  # Enemy -> float time to next footstep ping
var seen := {}  # Enemy -> bool, last frame's verdict


class Shade extends Node2D:
	var vision: Vision

	func _draw() -> void:
		var p: Vector2 = vision.game.player.global_position
		for r in vision.occluders():
			if r.has_point(p):
				continue
			var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
			# Extrude every edge that faces away from Toa (top, right, bottom, left); together they
			# cover exactly what the box hides.
			var back := [p.y > r.position.y, p.x < r.end.x, p.y < r.end.y, p.x > r.position.x]
			for i in 4:
				if not back[i]:
					continue
				var a: Vector2 = c[i]
				var b: Vector2 = c[(i + 1) % 4]
				draw_colored_polygon(PackedVector2Array([a, b, b + (b - p).normalized() * REACH,
					a + (a - p).normalized() * REACH]), Color.BLACK)


func setup(g: Node, level: Level) -> void:
	game = g
	for cells in level.wall_rects():
		rects.append(Rect2(Vector2(cells.position) * Level.CELL, Vector2(cells.size) * Level.CELL))
	# Shade polygons overlap; the group flattens them so the overlap is not darker.
	shade = CanvasGroup.new()
	shade.self_modulate = Color(1, 1, 1, SHADE_ALPHA)
	shade.light_mask = 0
	shade.show_behind_parent = true
	add_child(shade)
	var s := Shade.new()
	s.vision = self
	s.light_mask = 0
	shade.add_child(s)


func active() -> bool:
	return game.player != null and not game.hide_roofs and game.cam_focus == null


## Wall boxes and closed doors near Toa.
func occluders() -> Array[Rect2]:
	var p: Vector2 = game.player.global_position
	var out: Array[Rect2] = []
	for r in rects:
		if r.get_center().distance_to(p) - r.size.length() * 0.5 < CULL:
			out.append(r)
	for d in get_tree().get_nodes_in_group("doors"):
		if not d.open:
			out.append(d.sprite_rect)
	return out


func can_see(e: Node2D) -> bool:
	return not active() or seen.get(e, false)


func _process(delta: float) -> void:
	if game.player == null:
		return
	var on := active()
	shade.visible = on
	shade.get_child(0).queue_redraw()
	var p: Vector2 = game.player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := p.distance_to(e.global_position)
		var target := 1.0
		var visible_now := true
		if on:
			visible_now = d < CULL and _los(p, e.global_position)
			target = 1.0 if visible_now else (0.35 if d < SENSE else 0.0)
		if seen.get(e, false) and not visible_now and not e.is_dead():
			ghosts[e] = [e.global_position, GHOST_TIME]
		elif visible_now:
			ghosts.erase(e)
		seen[e] = visible_now
		e.modulate.a = move_toward(e.modulate.a, target, delta * 8.0)
		if visible_now or e.is_dead() or d > STEP_RANGE or e.velocity.length() < 40.0:
			continue
		steps[e] = steps.get(e, 0.0) - delta
		if steps[e] <= 0.0:
			steps[e] = STEP_EVERY
			game.hud.ping(e.global_position, false)
	for e in ghosts.keys():
		ghosts[e][1] -= delta
		if ghosts[e][1] <= 0.0 or not is_instance_valid(e):
			ghosts.erase(e)
	queue_redraw()


## Toa sees a body if a ray reaches its centre or either shoulder, so corners do not hide half a man.
func _los(from: Vector2, to: Vector2) -> bool:
	var side := (to - from).orthogonal().normalized() * 8.0
	return game.has_los(from, to) or game.has_los(from, to + side) or game.has_los(from, to - side)


func _draw() -> void:
	if not active():
		return
	for e in ghosts:
		var k: float = ghosts[e][1] / GHOST_TIME
		var pos: Vector2 = ghosts[e][0]
		draw_arc(pos, 10.0, 0.0, TAU, 20, Color(1.0, 0.4, 0.35, 0.55 * k), 1.5)
		draw_circle(pos, 2.5, Color(1.0, 0.4, 0.35, 0.55 * k))
