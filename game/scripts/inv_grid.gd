class_name InvGrid
extends RefCounted
## Rectangular inventory grid. Items are dictionaries from ItemDB.make with x, y and rot set on placement.

var w := 1
var h := 1
var items: Array = []


func _init(width: int = 1, height: int = 1) -> void:
	w = width
	h = height


func fits(item: Dictionary, x: int, y: int, rot: bool, ignore = null) -> bool:
	var s := ItemDB.size_of(item, rot)
	if x < 0 or y < 0 or x + s.x > w or y + s.y > h:
		return false
	var r := Rect2i(x, y, s.x, s.y)
	for other in items:
		if is_same(other, ignore) or is_same(other, item):
			continue
		if r.intersects(rect_of(other)):
			return false
	return true


func add_at(item: Dictionary, x: int, y: int, rot: bool) -> bool:
	if not fits(item, x, y, rot):
		return false
	item["x"] = x
	item["y"] = y
	item["rot"] = rot
	items.append(item)
	return true


## Places the item in the first free spot, trying its current rotation first.
func auto_add(item: Dictionary) -> bool:
	for rot in [item.get("rot", false), not item.get("rot", false)]:
		for y in h:
			for x in w:
				if add_at(item, x, y, rot):
					return true
	return false


## Dictionaries compare by value, so match by identity.
func has(item: Dictionary) -> bool:
	return items.any(func(i): return is_same(i, item))


func remove(item: Dictionary) -> void:
	for i in items.size():
		if is_same(items[i], item):
			items.remove_at(i)
			return


func rect_of(item: Dictionary) -> Rect2i:
	var s := ItemDB.size_of(item, item["rot"])
	return Rect2i(item["x"], item["y"], s.x, s.y)


func item_at(cell: Vector2i):
	for item in items:
		if rect_of(item).has_point(cell):
			return item
	return null


func total_value() -> int:
	var v := 0
	for item in items:
		v += ItemDB.value_of(item)
	return v


func total_weight() -> float:
	var wt := 0.0
	for item in items:
		wt += ItemDB.weight_of(item)
	return wt
