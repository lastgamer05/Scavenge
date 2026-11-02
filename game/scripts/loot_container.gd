class_name LootContainer
extends Node2D
## Something to search: crate, locker, safe, corpse or a pile of dropped items.

var kind := "crate"
var title := ""
var grid: InvGrid
var searched := false
var sprite: Sprite2D


func setup(container_kind: String, fill_loot: bool = true) -> void:
	kind = container_kind
	var table: Dictionary = ItemDB.LOOT[kind]
	title = table["title"]
	var s: Vector2i = table["size"]
	grid = InvGrid.new(s.x, s.y)
	if fill_loot:
		ItemDB.fill(grid, kind)


func _ready() -> void:
	add_to_group("containers")
	if kind != "corpse":
		sprite = Sprite2D.new()
		sprite.texture = PixelArt.texture("prop:" + kind)
		sprite.scale = Vector2.ONE * CharacterRig.SCALE
		add_child(sprite)


## Called when the inventory screen closes on this container.
func on_closed() -> void:
	searched = true
	if kind == "pile" and grid.items.is_empty():
		queue_free()
	queue_redraw()



func _draw() -> void:
	if not searched and kind != "corpse" and kind != "pile":
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(1, 0.9, 0.6, 0.35), 2.0)
	if sprite != null and searched and grid.items.is_empty():
		sprite.modulate = Color(0.55, 0.55, 0.55)
