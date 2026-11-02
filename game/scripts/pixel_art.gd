class_name PixelArt
extends RefCounted
## Procedural 16px pixel art: ground tiles, walls, roofs, characters, weapons and props.
## Everything is generated once and cached. Colours are drawn brighter than they appear,
## because the moonlight CanvasModulate darkens and blues the whole world.

const T := 16  # tile size in art pixels; one map cell = 16 art pixels = 32 world units
const OUTLINE := Color8(18, 14, 16)

const DIRT := [Color8(84, 76, 60), Color8(94, 85, 66), Color8(74, 67, 52)]
const WEED := [Color8(78, 92, 50), Color8(96, 110, 58)]
const COBBLE := [Color8(104, 104, 112), Color8(118, 118, 126), Color8(92, 92, 100)]
const COBBLE_GAP := Color8(58, 58, 64)
const WOOD := [Color8(122, 90, 60), Color8(108, 79, 52), Color8(132, 99, 66)]
const WOOD_SEAM := Color8(64, 46, 30)
const BRICK := [Color8(128, 66, 50), Color8(142, 76, 58), Color8(114, 58, 44)]
const MORTAR := Color8(70, 48, 40)
const WALL_TOP := [Color8(66, 48, 42), Color8(74, 54, 46)]
const SLATE := [Color8(74, 80, 92), Color8(84, 90, 102), Color8(66, 71, 82)]
const SLATE_LINE := Color8(44, 47, 56)
const RUST := Color8(92, 82, 64)

static var _cache := {}


static func _img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


static func _fill(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r, c)


static func _pick(rng: RandomNumberGenerator, arr: Array) -> Color:
	return arr[rng.randi() % arr.size()]


## Adds a 1px dark outline around every opaque pixel, for sprite readability.
static func _outline(img: Image) -> Image:
	var out := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() and img.get_pixel(n.x, n.y).a > 0.5:
					out.set_pixel(x, y, OUTLINE)
					break
	return out


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)


# ---------------------------------------------------------------- tiles

static func tile(kind: String, variant: int) -> Image:
	var key := "tile_%s_%d" % [kind, variant]
	if not _cache.has(key):
		var img: Image
		match kind:
			"dirt": img = _tile_dirt(variant)
			"cobble": img = _tile_cobble(variant)
			"wood": img = _tile_wood(variant)
			"rubble": img = _tile_rubble(variant)
			"wall_face": img = _tile_wall_face(variant)
			"wall_top": img = _tile_wall_top(variant)
			"roof": img = _tile_roof(variant)
			_: img = _tile_plate(variant)
		_cache[key] = img
	return _cache[key]


static func _tile_dirt(v: int) -> Image:
	var img := _img(T, T)
	var rng := _rng(100 + v)
	for y in T:
		for x in T:
			img.set_pixel(x, y, DIRT[0] if rng.randf() < 0.6 else _pick(rng, DIRT))
	for i in 6:
		img.set_pixel(rng.randi() % T, rng.randi() % T, Color8(60, 54, 42))
	if v >= 2:
		for i in 2:
			var bx := rng.randi_range(2, 12)
			var by := rng.randi_range(3, 13)
			for p in [Vector2i(0, 0), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(0, -2), Vector2i(2, -2)]:
				img.set_pixel(clampi(bx + p.x, 0, 15), clampi(by + p.y, 0, 15), WEED[(p.x + 4) % 2])
	return img


static func _tile_cobble(v: int) -> Image:
	var img := _img(T, T)
	var rng := _rng(200 + v)
	img.fill(COBBLE_GAP)
	for row in 4:
		var off := 0 if row % 2 == 0 else 3
		for col in range(-1, 3):
			var x0 := col * 6 + off
			var r := Rect2i(x0 + 1, row * 4 + 1, 5, 3).intersection(Rect2i(0, 0, T, T))
			if r.size.x <= 0:
				continue
			var c := _pick(rng, COBBLE)
			_fill(img, r, c)
			img.set_pixel(r.position.x, r.position.y, c.lightened(0.15))
			img.set_pixel(r.end.x - 1, r.end.y - 1, c.darkened(0.2))
	if v == 1:
		for i in 3:
			img.set_pixel(rng.randi() % T, rng.randi() % T, WEED[0])
	return img


static func _tile_wood(v: int) -> Image:
	var img := _img(T, T)
	var rng := _rng(300 + v)
	var row_colors := [WOOD[0], WOOD[1], WOOD[2], WOOD[1].darkened(0.06)]
	for row in 4:
		var c: Color = row_colors[row]
		_fill(img, Rect2i(0, row * 4, T, 4), c)
		_fill(img, Rect2i(0, row * 4 + 3, T, 1), WOOD_SEAM)
		if rng.randf() < 0.3:
			_fill(img, Rect2i(rng.randi_range(2, 13), row * 4, 1, 3), WOOD_SEAM)
		for i in 3:
			var gx := rng.randi() % (T - 3)
			_fill(img, Rect2i(gx, row * 4 + 1, 3, 1), c.darkened(0.1))
	if v == 2:
		_ellipse(img, rng.randf_range(5, 11), rng.randf_range(5, 11), 4.0, 2.5, Color8(82, 58, 38))  # old water stain
	elif v == 3:
		for i in 5:
			img.set_pixel(rng.randi() % T, rng.randi() % T, Color8(150, 150, 140))
	return img


static func _tile_rubble(v: int) -> Image:
	var img := _tile_dirt(v).duplicate()
	var rng := _rng(400 + v)
	for i in 3:
		var w := rng.randi_range(2, 4)
		var h := rng.randi_range(2, 3)
		var p := Vector2i(rng.randi_range(0, T - w), rng.randi_range(0, T - h))
		var c := _pick(rng, BRICK).lerp(Color8(100, 90, 80), 0.45) if i % 2 == 0 else _pick(rng, COBBLE)
		_fill(img, Rect2i(p.x, p.y + 1, w, h), Color8(40, 34, 28))
		_fill(img, Rect2i(p, Vector2i(w, h)), c)
		img.set_pixel(p.x, p.y, c.lightened(0.2))
	return img


static func _tile_wall_face(v: int) -> Image:
	var img := _img(T, T)
	var rng := _rng(500 + v)
	img.fill(MORTAR)
	for row in 4:
		var off := 0 if row % 2 == 0 else 4
		for col in range(-1, 3):
			var r := Rect2i(col * 8 + off, row * 4, 7, 3).intersection(Rect2i(0, 0, T, T))
			if r.size.x <= 0:
				continue
			var c := _pick(rng, BRICK).darkened(row * 0.06)
			_fill(img, r, c)
			_fill(img, Rect2i(r.position, Vector2i(r.size.x, 1)), c.lightened(0.12))
	_fill(img, Rect2i(0, T - 2, T, 2), Color8(40, 28, 24))
	if v == 1:
		_fill(img, Rect2i(rng.randi_range(2, 10), rng.randi_range(2, 8), 3, 3), Color8(46, 32, 28))
	return img


static func _tile_wall_top(v: int) -> Image:
	var img := _img(T, T)
	var rng := _rng(600 + v)
	img.fill(WALL_TOP[0])
	for i in 10:
		img.set_pixel(rng.randi() % T, rng.randi() % T, WALL_TOP[1])
	for y in [5, 11]:
		_fill(img, Rect2i(0, y, T, 1), Color8(52, 38, 34))
	if v >= 2:
		_fill(img, Rect2i(0, 0, T, 2), Color8(112, 80, 66))
	return img


static func _tile_roof(v: int) -> Image:
	var img := _img(T, T)
	var rng := _rng(700 + v)
	for row in 4:
		var off := 0 if row % 2 == 0 else 2
		for col in range(-1, 4):
			var r := Rect2i(col * 4 + off, row * 4, 4, 4).intersection(Rect2i(0, 0, T, T))
			if r.size.x <= 0:
				continue
			var c := _pick(rng, SLATE)
			_fill(img, r, c)
			_fill(img, Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), SLATE_LINE)
			img.set_pixel(r.position.x, r.position.y, c.lightened(0.1))
	if v == 2:
		_ellipse(img, rng.randf_range(4, 12), rng.randf_range(4, 12), 3.5, 2.5, RUST)
	return img


static func _tile_plate(_v: int) -> Image:
	var img := _img(T, T)
	img.fill(Color8(70, 82, 74))
	_fill(img, Rect2i(0, 0, T, 1), Color8(96, 110, 100))
	_fill(img, Rect2i(0, T - 1, T, 1), Color8(46, 54, 48))
	for p in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
		img.set_pixel(p.x, p.y, Color8(140, 150, 140))
	return img


## Soft shadow cast onto floor by a wall above (top) or to the left (left).
static func shadow(side: String) -> Image:
	var key := "shadow_" + side
	if not _cache.has(key):
		var img := _img(T, T)
		for i in 5:
			var a := 0.5 * (1.0 - i / 5.0)
			if side == "top":
				_fill(img, Rect2i(0, i, T, 1), Color(0, 0, 0, a))
			else:
				_fill(img, Rect2i(i, 0, 1, T), Color(0, 0, 0, a * 0.7))
		_cache[key] = img
	return _cache[key]


# ---------------------------------------------------------------- sprites

static func texture(key: String) -> ImageTexture:
	var tkey := "tex_" + key
	if not _cache.has(tkey):
		_cache[tkey] = ImageTexture.create_from_image(_build_sprite(key))
	return _cache[tkey]


static func _build_sprite(key: String) -> Image:
	var parts := key.split(":")
	match parts[0]:
		"toa":
			return _character(Color8(70, 86, 66), Color8(84, 84, 88), Color8(116, 82, 50), true)
		"scav":
			var palettes := [[Color8(116, 70, 56), Color8(70, 58, 50)], [Color8(96, 92, 70), Color8(60, 52, 44)],
				[Color8(84, 70, 96), Color8(58, 50, 60)]]
			var p: Array = palettes[int(parts[1]) % palettes.size()]
			return _character(p[0], p[1], Color8(150, 40, 40), false)
		"centra":
			return _character(Color8(70, 82, 104), Color8(52, 60, 76), Color8(170, 40, 36), false)
		"npc":
			var looks := {
				"leader": [Color8(120, 46, 40), Color8(60, 50, 46), Color8(200, 170, 90)],
				"weapons": [Color8(110, 80, 52), Color8(70, 56, 44), Color8(60, 60, 66)],
				"doctor": [Color8(196, 196, 186), Color8(90, 80, 72), Color8(180, 50, 50)],
				"junk": [Color8(96, 110, 70), Color8(110, 90, 60), Color8(150, 120, 60)],
				"informant": [Color8(52, 52, 64), Color8(40, 40, 48), Color8(120, 160, 190)],
			}
			var l: Array = looks.get(parts[1], looks["junk"])
			return _character(l[0], l[1], l[2], false)
		"weapon":
			return _weapon(parts[1])
		"prop":
			match parts[1]:
				"crate": return _prop_crate()
				"locker": return _prop_locker()
				"safe": return _prop_safe()
				"barrel": return _prop_barrel()
				"lamp": return _prop_lamp()
				_: return _prop_pile()
	return _img(1, 1)


## Top-down character facing +x (right). The pack sits on the back, the head toward the front.
static func _character(coat: Color, head: Color, accent: Color, pack: bool) -> Image:
	var img := _img(T, T)
	_ellipse(img, 8, 8, 4.5, 6.0, coat)
	_ellipse(img, 7, 8, 3.0, 5.0, coat.lightened(0.08))
	_fill(img, Rect2i(9, 3, 3, 2), coat.darkened(0.15))  # forward arm
	_fill(img, Rect2i(9, 11, 3, 2), coat.darkened(0.15))
	if pack:
		_fill(img, Rect2i(2, 4, 4, 8), accent)
		_fill(img, Rect2i(2, 4, 4, 1), accent.lightened(0.2))
		_fill(img, Rect2i(3, 7, 2, 2), accent.darkened(0.3))
		_fill(img, Rect2i(5, 5, 1, 6), Color8(60, 44, 30))
	_ellipse(img, 9, 8, 2.6, 2.6, head)
	img.set_pixel(9, 7, head.lightened(0.25))
	if pack:
		_fill(img, Rect2i(11, 7, 1, 2), Color8(200, 160, 70))  # goggles
	else:
		_fill(img, Rect2i(10, 6, 1, 4), accent)  # bandana / cap band
	return _outline(img)


const WEAPON_SHAPES := {
	"pistol": [7, false], "silenced": [10, false], "smg": [9, false], "shotgun": [12, false],
	"rifle": [14, false], "bat": [11, true], "knife": [6, true],
}


static func _weapon(id: String) -> Image:
	var spec: Array = WEAPON_SHAPES.get(id, [6, false])
	var length: int = spec[0]
	var img := _img(length + 2, 6)
	var metal := Color8(54, 54, 60)
	var hi := Color8(120, 120, 130)
	match id:
		"bat":
			_fill(img, Rect2i(1, 2, length, 2), Color8(150, 104, 62))
			_fill(img, Rect2i(length - 3, 1, 4, 4), Color8(160, 112, 68))
			_fill(img, Rect2i(1, 2, 3, 2), Color8(60, 40, 30))
		"knife":
			_fill(img, Rect2i(1, 2, 2, 2), Color8(70, 50, 36))
			_fill(img, Rect2i(3, 2, length - 2, 2), Color8(180, 184, 190))
		_:
			_fill(img, Rect2i(1, 2, length, 2), metal)
			_fill(img, Rect2i(1, 2, length, 1), hi)
			_fill(img, Rect2i(2, 3, 2, 2), Color8(74, 54, 40))  # grip
			if id in ["rifle", "shotgun"]:
				_fill(img, Rect2i(1, 2, 3, 3), Color8(110, 76, 46))  # stock
			if id == "smg":
				_fill(img, Rect2i(5, 4, 2, 2), metal)  # magazine
			if id == "silenced":
				_fill(img, Rect2i(length - 3, 2, 4, 2), Color8(90, 110, 130))
	return _outline(img)


static func _prop_crate() -> Image:
	var img := _img(T, T)
	var wood := Color8(140, 98, 58)
	_fill(img, Rect2i(2, 2, 12, 12), wood)
	_fill(img, Rect2i(2, 2, 12, 1), wood.lightened(0.2))
	_fill(img, Rect2i(2, 6, 12, 1), wood.darkened(0.3))
	_fill(img, Rect2i(2, 10, 12, 1), wood.darkened(0.3))
	_fill(img, Rect2i(2, 2, 1, 12), Color8(80, 60, 40))
	_fill(img, Rect2i(13, 2, 1, 12), Color8(80, 60, 40))
	return _outline(img)


static func _prop_locker() -> Image:
	var img := _img(T, T)
	var steel := Color8(104, 116, 124)
	_fill(img, Rect2i(3, 1, 10, 14), steel)
	_fill(img, Rect2i(3, 1, 10, 1), steel.lightened(0.25))
	_fill(img, Rect2i(8, 1, 1, 14), steel.darkened(0.35))
	for y in [4, 6, 8]:
		_fill(img, Rect2i(4, y, 3, 1), steel.darkened(0.3))
		_fill(img, Rect2i(9, y, 3, 1), steel.darkened(0.3))
	return _outline(img)


static func _prop_safe() -> Image:
	var img := _img(T, T)
	var steel := Color8(64, 68, 76)
	_fill(img, Rect2i(2, 2, 12, 12), steel)
	_fill(img, Rect2i(2, 2, 12, 1), steel.lightened(0.3))
	_ellipse(img, 8, 8, 2.5, 2.5, Color8(190, 150, 70))
	img.set_pixel(8, 8, Color8(80, 60, 30))
	return _outline(img)


static func _prop_pile() -> Image:
	var img := _img(T, T)
	_ellipse(img, 7, 9, 5, 3.5, Color8(110, 92, 70))
	_fill(img, Rect2i(8, 5, 4, 3), Color8(90, 100, 110))
	_fill(img, Rect2i(4, 7, 3, 2), Color8(140, 70, 50))
	return _outline(img)


static func _prop_barrel() -> Image:
	var img := _img(T, T)
	_ellipse(img, 8, 8, 6, 6, Color8(126, 70, 46))
	_ellipse(img, 8, 8, 6, 6, Color8(126, 70, 46))
	_ellipse(img, 8, 8, 4.5, 4.5, Color8(30, 22, 20))
	_fill(img, Rect2i(2, 8, 1, 1), Color8(160, 100, 60))
	return _outline(img)


static func _prop_lamp() -> Image:
	var img := _img(T, T)
	_ellipse(img, 8, 8, 3, 3, Color8(50, 52, 56))
	_ellipse(img, 8, 8, 2, 2, Color8(255, 220, 150))
	return _outline(img)
