class_name WeaponPickup
extends Node2D
## A weapon lying on the floor or flying after a throw. Thrown weapons stun enemies on hit.

var weapon_id := "pistol"
var ammo := 0
var velocity := Vector2.ZERO
var thrown := false
var spin := 0.0
var game: Node


func _ready() -> void:
	add_to_group("pickups")
	rotation = randf() * TAU
	if thrown:
		spin = 22.0


func _physics_process(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	var from := global_position
	var to := from + velocity * delta
	var mask := 1 | (4 if thrown else 0)
	var q := PhysicsRayQueryParameters2D.create(from, to, mask)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var c = hit["collider"]
		if thrown and c is Enemy:
			c.stun(velocity.normalized(), 1.8)
			game.add_shake(3.0)
			velocity = -velocity * 0.2
			thrown = false
		else:
			global_position = hit["position"] + hit["normal"] * 3.0
			velocity = velocity.bounce(hit["normal"]) * 0.35
		return
	global_position = to
	rotation += spin * delta
	spin = move_toward(spin, 0.0, 40.0 * delta)
	velocity = velocity.move_toward(Vector2.ZERO, (700.0 if thrown else 1400.0) * delta)
	if thrown and velocity.length() < 220.0:
		thrown = false
	if velocity.length() < 8.0:
		velocity = Vector2.ZERO


func _draw() -> void:
	var wd := WeaponDB.get_data(weapon_id)
	var length: float = maxf(wd["length"], 8.0)
	var r := Rect2(-length * 0.5, -2.5, length, 5)
	draw_rect(r.grow(2.0), Color(1, 1, 1, 0.25))
	draw_rect(r, WeaponDB.color_of(weapon_id))
	if WeaponDB.is_gun(weapon_id) and ammo <= 0:
		draw_line(Vector2(-4, -4), Vector2(4, 4), Color(0.9, 0.3, 0.3), 1.5)
