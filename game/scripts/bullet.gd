class_name Bullet
extends Node2D
## Ray-cast projectile: sweeps from last to next position each physics frame.

const SPEED := 1500.0
const ENEMY_SPEED := 900.0  # slow enough to sidestep at range

var velocity := Vector2.ZERO
var from_player := false
var exclude: Array[RID] = []
var life := 1.0
var game: Node


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + velocity * delta
	# Player bullets hit walls and enemies; enemy bullets hit walls and the player.
	var mask := 1 | (4 if from_player else 2)
	var q := PhysicsRayQueryParameters2D.create(from, to, mask, exclude)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var c = hit["collider"]
		if c.has_method("take_hit"):
			c.take_hit(velocity.normalized(), from_player)
		else:
			game.spawn_fx("spark", hit["position"])
		queue_free()
		return
	global_position = to
	life -= delta
	if life <= 0.0:
		queue_free()


func _draw() -> void:
	var col := Color(1.0, 0.92, 0.55) if from_player else Color(1.0, 0.5, 0.35)
	draw_line(Vector2.ZERO, -velocity.normalized() * 16.0, col, 2.0)
