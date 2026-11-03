extends SceneTree
## Turns a generated sheet (magenta background) into clean pixel sprites.
##
## Usage:
##   godot --headless --path game --script res://tools/import_sprites.gd -- <sheet.png> <name> [options]
##
## Options:
##   poses=a,b,c,d   frame names in reading order (default unarmed,rifle,pistol,melee)
##   grid=CxR        sheet layout (default 2x2)
##   mode=icon       fit each cell into size=N pixels instead of character scaling
##   size=N          icon mode: longest side in art pixels (default 24)
##   greencross=name turn strong reds in that frame green (no red-cross emblem on medicine)
##   noemblem        paint over near-white insignia with the surrounding colour
##                   (generated armbands can come out with symbols we do not want)
##
## Character mode scales every sheet by the torso (limbs and weapons eroded away), so a bat
## sticking out does not shrink the body, and centres the torso in each image so a centred
## Sprite2D rotates around the shoulders. Writes res://assets/sprites/<name>_<pose>.png.

const TORSO_H := 13.0  # art pixels across the eroded torso
const OUT_DIR := "res://assets/sprites/"
const MIN_PIECE := 24


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <sheet.png> <name> [options]")
		quit(1)
		return
	var opts := {"poses": "unarmed,rifle,pistol,melee", "grid": "2x2", "mode": "sprite", "size": "24"}
	for a in args.slice(2):
		var kv: PackedStringArray = a.split("=")
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var grid: PackedStringArray = opts["grid"].split("x")
	var cols := int(grid[0])
	var rows := int(grid[1])
	var cw := img.get_width() / cols
	var ch := img.get_height() / rows
	var names: PackedStringArray = opts["poses"].split(",")
	var cells := []
	for r in rows:
		for c in cols:
			cells.append(Rect2i(c * cw, r * ch, cw, ch))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var boxes := cells.map(func(q): return _bbox(img, q))
	var factor := 1.0
	if opts["mode"] == "sprite":
		var base: Rect2i = boxes[0]
		var f0: float = base.size.y / 18.0
		var probe := _downsample(img, base, Vector2(base.get_center()), f0)
		factor = f0 * _torso(probe)[0] / TORSO_H
	for i in mini(names.size(), cells.size()):
		var box: Rect2i = boxes[i]
		if box.size.x <= 1:
			continue
		var out: Image
		if opts["mode"] == "icon":
			var f: float = maxf(box.size.x, box.size.y) / float(opts["size"])
			out = _downsample(img, box, Vector2(box.get_center()), f)
		else:
			out = _downsample(img, box, Vector2(box.get_center()), factor)
			_attach_pieces(out)
			out = _recenter(out, _torso(out)[1])
		if opts.has("noemblem"):
			_scrub_light(out)
		if opts.has("greencross") and names[i] == opts["greencross"]:
			_recolor_red(out)
		var path: String = OUT_DIR + "%s_%s.png" % [args[1], names[i]]
		out.save_png(ProjectSettings.globalize_path(path))
		print("%s %dx%d" % [path, out.get_width(), out.get_height()])
	quit()


## [height, centroid] of the pixels that survive a 5x5 erosion: the torso without thin limbs or weapons.
func _torso(img: Image) -> Array:
	var sum := Vector2.ZERO
	var n := 0
	var lo := 1e9
	var hi := -1e9
	for y in range(2, img.get_height() - 2):
		for x in range(2, img.get_width() - 2):
			var solid := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if img.get_pixel(x + dx, y + dy).a == 0.0:
						solid = false
						break
				if not solid:
					break
			if solid:
				sum += Vector2(x, y)
				n += 1
				lo = minf(lo, y)
				hi = maxf(hi, y)
	if n == 0:
		return [TORSO_H, Vector2(img.get_size()) * 0.5]
	return [hi - lo + 5.0, sum / n]


## Pads/crops so `center` lands in the middle of the image.
func _recenter(img: Image, center: Vector2) -> Image:
	var c := Vector2i(center.round())
	var half := Vector2i(maxi(c.x, img.get_width() - c.x), maxi(c.y, img.get_height() - c.y)) + Vector2i.ONE
	var out := Image.create_empty(half.x * 2, half.y * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), half - c)
	return out


static func _is_key(c: Color) -> bool:
	return (c.r + c.b) * 0.5 - c.g > 0.45


func _bbox(img: Image, area: Rect2i) -> Rect2i:
	var lo := area.end
	var hi := area.position
	for y in range(area.position.y, area.end.y, 2):
		for x in range(area.position.x, area.end.x, 2):
			if not _is_key(img.get_pixel(x, y)):
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _centroid(img: Image, area: Rect2i) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for y in range(area.position.y, area.end.y, 2):
		for x in range(area.position.x, area.end.x, 2):
			if not _is_key(img.get_pixel(x, y)):
				sum += Vector2(x, y)
				n += 1
	return sum / maxi(n, 1)


func _downsample(img: Image, box: Rect2i, pivot: Vector2, f: float) -> Image:
	var half := Vector2(maxf(pivot.x - box.position.x, box.end.x - pivot.x), maxf(pivot.y - box.position.y, box.end.y - pivot.y))
	var size := Vector2i(int(ceil(half.x / f)) * 2 + 2, int(ceil(half.y / f)) * 2 + 2)
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for j in size.y:
		for i in size.x:
			var center := pivot + (Vector2(i, j) - Vector2(size) * 0.5 + Vector2(0.5, 0.5)) * f
			var votes := {}
			var key_votes := 0
			for sy in 3:
				for sx in 3:
					var p := Vector2i(center + (Vector2(sx, sy) - Vector2.ONE) * f * 0.3)
					if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
						key_votes += 1
						continue
					var c := img.get_pixel(p.x, p.y)
					if _is_key(c):
						key_votes += 1
						continue
					var q := Color(snappedf(c.r, 1.0 / 24.0), snappedf(c.g, 1.0 / 24.0), snappedf(c.b, 1.0 / 24.0))
					votes[q] = votes.get(q, 0) + 1
			if votes.is_empty() or key_votes >= 5:
				continue
			var best: Color = votes.keys()[0]
			for q in votes:
				if votes[q] > votes[best]:
					best = q
			out.set_pixel(i, j, Color(best, 1.0))
	# Drop stray specks: connected pieces (8-way) smaller than MIN_PIECE pixels.
	var seen := {}
	for j in size.y:
		for i in size.x:
			var start := Vector2i(i, j)
			if out.get_pixel(i, j).a == 0.0 or seen.has(start):
				continue
			var piece: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				piece.append(p)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := p + Vector2i(dx, dy)
						if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and not seen.has(n) and out.get_pixel(n.x, n.y).a > 0.0:
							seen[n] = true
							stack.append(n)
			if piece.size() < MIN_PIECE:
				for p in piece:
					out.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	return out


func _pieces(img: Image) -> Array:
	var size := img.get_size()
	var seen := {}
	var pieces := []
	for j in size.y:
		for i in size.x:
			var start := Vector2i(i, j)
			if img.get_pixel(i, j).a == 0.0 or seen.has(start):
				continue
			var piece: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				piece.append(p)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := p + Vector2i(dx, dy)
						if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and not seen.has(n) and img.get_pixel(n.x, n.y).a > 0.0:
							seen[n] = true
							stack.append(n)
			pieces.append(piece)
	pieces.sort_custom(func(a, b): return a.size() > b.size())
	return pieces


## Generated sheets sometimes draw the held gun a few pixels in front of the hands.
## Slide every loose piece back along -x until it touches the body; drop pieces that never would.
func _attach_pieces(img: Image) -> void:
	var pieces := _pieces(img)
	if pieces.size() < 2:
		return
	var body := {}
	for p in pieces[0]:
		body[p] = true
	for k in range(1, pieces.size()):
		var piece: Array = pieces[k]
		var shift := -1
		for s in range(1, 14):
			if piece.any(func(p): return _touches(body, p - Vector2i(s, 0))):
				shift = s
				break
		var colors := piece.map(func(p): return img.get_pixel(p.x, p.y))
		for p in piece:
			img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		if shift < 0:
			continue  # not in front of the hands: stray bit from a neighbouring pose
		for idx in piece.size():
			var q: Vector2i = piece[idx] - Vector2i(shift, 0)
			img.set_pixel(q.x, q.y, colors[idx])
			body[q] = true


static func _touches(body: Dictionary, p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if body.has(p + Vector2i(dx, dy)):
				return true
	return false


## Replace near-white pixels with the average of their coloured neighbours.
func _scrub_light(img: Image) -> void:
	var src: Image = img.duplicate()
	for j in img.get_height():
		for i in img.get_width():
			var c := src.get_pixel(i, j)
			if c.a == 0.0 or minf(c.r, minf(c.g, c.b)) < 0.62:
				continue
			var sum := Color(0, 0, 0, 0)
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var q: Vector2i = Vector2i(i, j) + d
				if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
					continue
				var nc := src.get_pixel(q.x, q.y)
				if nc.a > 0.0 and minf(nc.r, minf(nc.g, nc.b)) < 0.62 and nc.get_luminance() > 0.12:
					sum += nc
					n += 1
			if n > 0:
				img.set_pixel(i, j, Color(sum.r / n, sum.g / n, sum.b / n, 1.0))


func _recolor_red(img: Image) -> void:
	for j in img.get_height():
		for i in img.get_width():
			var c := img.get_pixel(i, j)
			if c.a > 0.0 and c.r > 0.55 and c.g < 0.35 and c.b < 0.35:
				img.set_pixel(i, j, Color(0.25, c.r * 0.75, 0.3, 1.0))
