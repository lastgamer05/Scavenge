extends SceneTree
## Turns a generated 2x2 character sheet (magenta background) into clean pixel sprites.
##
## Usage:
##   godot --headless --path game --script res://tools/import_sprites.gd -- <sheet.png> <name>
##
## Writes res://assets/sprites/<name>_{unarmed,rifle,pistol,melee}.png. Each sprite is
## downsampled by majority vote onto a real pixel grid and padded so the body pivot
## (the centre of the shoulders) sits at the image centre, ready for a centred Sprite2D.

const POSES := ["unarmed", "rifle", "pistol", "melee"]  # top-left, top-right, bottom-left, bottom-right
const TARGET_H := 18.0  # art pixels from shoulder to shoulder in the unarmed pose
const OUT_DIR := "res://assets/sprites/"
const MIN_PIECE := 12


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <sheet.png> <name>")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width() / 2
	var h := img.get_height() / 2
	var quads := [Rect2i(0, 0, w, h), Rect2i(w, 0, w, h), Rect2i(0, h, w, h), Rect2i(w, h, w, h)]
	var boxes := quads.map(func(q): return _bbox(img, q))
	var base: Rect2i = boxes[0]
	var factor: float = base.size.y / TARGET_H
	var pivot_off: float = _centroid(img, base).x - base.position.x
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for i in 4:
		var box: Rect2i = boxes[i]
		# The back pack sits on the body axis, so its column centroid gives the pivot height.
		var back := Rect2i(box.position, Vector2i(int(base.size.x * 0.3), box.size.y))
		var pivot := Vector2(box.position.x + pivot_off, _centroid(img, back).y)
		var out := _downsample(img, box, pivot, factor)
		var path: String = OUT_DIR + "%s_%s.png" % [args[1], POSES[i]]
		out.save_png(ProjectSettings.globalize_path(path))
		print("%s %dx%d" % [path, out.get_width(), out.get_height()])
	quit()


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
