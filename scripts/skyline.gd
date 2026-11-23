extends Node2D

## Code-drawn far background for stages that have no painting yet. A theme is
## a sky, an optional band of sea, and two or three layers of silhouettes
## (cliffs, cranes, ships, container stacks, a bridge, a tower) that slide at
## different speeds as the camera moves. Adding the stage's painting to the
## project replaces it. The practice cards draw the same scene with paint().

const VIEW := Vector2(1152.0, 648.0)

## Generated layers per theme, built once.
static var _cache := {}

@export var theme_name := "coast"


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var scroll := camera.get_screen_center_position() if camera else VIEW * 0.5
	paint(self, Rect2(Vector2.ZERO, VIEW), theme_name, scroll, 1.0)


## Draws the theme into `rect`, as seen from a camera centred on `scroll`.
static func paint(canvas: CanvasItem, rect: Rect2, name: String, scroll: Vector2, alpha: float) -> void:
	var theme: Dictionary = _theme(name)
	var scale := rect.size.y / VIEW.y
	# The full screen needs no trimming; a card's picture has to stay inside it.
	var clip := not rect.is_equal_approx(Rect2(Vector2.ZERO, VIEW))
	_sky(canvas, rect, theme, alpha)
	for layer: Dictionary in theme["layers"]:
		var width: float = layer["width"]
		var shift := fposmod(scroll.x * float(layer["factor"]), width)
		var lift := (scroll.y - 342.0) * float(layer["factor"]) * float(layer.get("rise", 0.35))
		for tile in [0.0, width]:
			var origin := Vector2(tile - shift, -lift)
			for shape: Array in layer["shapes"]:
				_draw_shape(canvas, rect, scale, origin, shape, layer["color"], alpha, clip)


static func _sky(canvas: CanvasItem, rect: Rect2, theme: Dictionary, alpha: float) -> void:
	var top: Color = theme["top"]
	var low: Color = theme["low"]
	var horizon := rect.position.y + rect.size.y * float(theme["horizon"])
	canvas.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, horizon), Vector2(rect.position.x, horizon)]),
		PackedColorArray([Color(top, alpha), Color(top, alpha), Color(low, alpha), Color(low, alpha)]))
	var below: Color = theme.get("sea", low.darkened(0.45))
	canvas.draw_polygon(PackedVector2Array([Vector2(rect.position.x, horizon), Vector2(rect.end.x, horizon), rect.end,
		Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([Color(below.lightened(0.12), alpha), Color(below.lightened(0.12), alpha), Color(below.darkened(0.4), alpha),
			Color(below.darkened(0.4), alpha)]))
	# A soft glow low in the sky: the sun behind haze, or harbour light.
	var glow: Color = theme["glow"]
	var at := rect.position + rect.size * Vector2(theme["glow_at"])
	for ring in 5:
		var radius := rect.size.y * (0.12 + ring * 0.09)
		canvas.draw_circle(at, radius, Color(glow, 0.07 * alpha))
	if theme.has("sea"):
		# Glints on the water under the glow.
		for row in 6:
			var y := horizon + (row + 1) * rect.size.y * 0.035
			if y > rect.end.y:
				break
			var half := rect.size.x * (0.05 + row * 0.025)
			canvas.draw_line(Vector2(maxf(at.x - half, rect.position.x), y), Vector2(minf(at.x + half, rect.end.x), y),
				Color(glow, (0.22 - row * 0.03) * alpha), 1.5 + row * 0.4)


static func _draw_shape(canvas: CanvasItem, rect: Rect2, scale: float, origin: Vector2, shape: Array, tint: Color, alpha: float, clip: bool) -> void:
	var kind: String = shape[0]
	match kind:
		"poly":
			var source: PackedVector2Array = shape[1]
			var points := PackedVector2Array()
			var low := INF
			var high := -INF
			for point in source:
				var placed := _place(rect, scale, origin, point)
				low = minf(low, placed.x)
				high = maxf(high, placed.x)
				points.append(placed)
			if high < rect.position.x or low > rect.end.x:
				return
			var color := Color(shape[2] if shape.size() > 2 else tint, alpha)
			if not clip:
				canvas.draw_colored_polygon(points, color)
				return
			var frame := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(points, frame):
				if piece.size() >= 3:
					canvas.draw_colored_polygon(piece, color)
		"rect":
			var box: Rect2 = shape[1]
			var a := _place(rect, scale, origin, box.position)
			var b := _place(rect, scale, origin, box.end)
			var clipped := Rect2(a, b - a).intersection(rect)
			if clipped.has_area():
				canvas.draw_rect(clipped, Color(shape[2] if shape.size() > 2 else tint, alpha))
		"line":
			var a := _place(rect, scale, origin, shape[1])
			var b := _place(rect, scale, origin, shape[2])
			if maxf(a.x, b.x) < rect.position.x or minf(a.x, b.x) > rect.end.x:
				return
			a = Vector2(clampf(a.x, rect.position.x, rect.end.x), clampf(a.y, rect.position.y, rect.end.y))
			b = Vector2(clampf(b.x, rect.position.x, rect.end.x), clampf(b.y, rect.position.y, rect.end.y))
			canvas.draw_line(a, b, Color(shape[4] if shape.size() > 4 else tint, alpha), maxf(1.0, float(shape[3]) * scale))
		"light":
			var at := _place(rect, scale, origin, shape[1])
			if rect.has_point(at):
				var color: Color = shape[2]
				canvas.draw_circle(at, 9.0 * scale, Color(color, 0.16 * alpha))
				canvas.draw_circle(at, 2.2 * maxf(scale, 0.6), Color(color, 0.9 * alpha))


static func _place(rect: Rect2, scale: float, origin: Vector2, point: Vector2) -> Vector2:
	return rect.position + (point + origin) * scale


static func _theme(name: String) -> Dictionary:
	if not _cache.has(name):
		_cache[name] = _build(name)
	return _cache[name]


static func _build(name: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var amber := Color("#ffb46e")
	var cyan := Color("#8be9ff")
	match name:
		"bridge":
			return {
				"top": Color("#0c1a24"), "low": Color("#3c4d57"), "glow": Color("#c9d9de"), "glow_at": Vector2(0.3, 0.4),
				"horizon": 0.72, "sea": Color("#14262f"),
				"layers": [
					_layer(0.03, 2400.0, Color("#1b2a33"), _cliffs(rng, 2400.0, 360.0, 200.0, 7)),
					_layer(0.1, 2600.0, Color("#121e25"), _truss(0.0, 2600.0, 300.0) + _piers(2600.0, 300.0, 470.0)),
					_layer(0.2, 2800.0, Color("#0b141a"), _cliffs(rng, 2800.0, 560.0, 150.0, 5)),
				],
			}
		"railyard", "yard":
			var stacks := _stacks(rng, 2600.0, 430.0, name == "yard")
			return {
				"top": Color("#101a26"), "low": Color("#4b4a52"), "glow": amber, "glow_at": Vector2(0.65, 0.62),
				"horizon": 0.7,
				"layers": [
					_layer(0.03, 2400.0, Color("#1a2530"), _cranes(rng, 2400.0, 400.0, 5, 210.0)),
					_layer(0.1, 2600.0, Color("#141d25"), stacks + _masts(rng, 2600.0, 440.0, amber)),
					_layer(0.2, 2800.0, Color("#0c1218"), _cars(rng, 2800.0, 560.0)),
				],
			}
		"wharf", "dock":
			var night := name == "dock"
			return {
				"top": Color("#091019") if night else Color("#14202b"), "low": Color("#2f3c48") if night else Color("#5b5a5c"),
				"glow": cyan if night else amber, "glow_at": Vector2(0.7, 0.6), "horizon": 0.66, "sea": Color("#10222c"),
				"layers": [
					_layer(0.03, 2400.0, Color("#18232d"), _ship(500.0, 430.0, 900.0, rng) + _cranes(rng, 2400.0, 420.0, 4, 260.0)),
					_layer(0.1, 2600.0, Color("#111a22"), _cranes(rng, 2600.0, 470.0, 3, 330.0) + _masts(rng, 2600.0, 470.0, amber)),
					_layer(0.2, 2800.0, Color("#0a1117"), _stacks(rng, 2800.0, 600.0, false)),
				],
			}
		"breakwater":
			return {
				"top": Color("#0e1a24"), "low": Color("#55606a"), "glow": Color("#d6e4e8"), "glow_at": Vector2(0.55, 0.55),
				"horizon": 0.6, "sea": Color("#132833"),
				"layers": [
					_layer(0.02, 2400.0, Color("#26333c"), _clouds(rng, 2400.0)),
					_layer(0.08, 2600.0, Color("#111c23"), _lighthouse(1500.0, 420.0, amber) + _waves(rng, 2600.0, 470.0)),
					_layer(0.18, 2800.0, Color("#0a1218"), _waves(rng, 2800.0, 560.0)),
				],
			}
		"tower":
			return {
				"top": Color("#0b1520"), "low": Color("#3a4650"), "glow": cyan, "glow_at": Vector2(0.4, 0.7),
				"horizon": 0.78, "sea": Color("#10202a"),
				"layers": [
					_layer(0.03, 2400.0, Color("#16212b"), _cranes(rng, 2400.0, 520.0, 4, 300.0)),
					_layer(0.08, 2600.0, Color("#101920"), _lattice(700.0, 640.0, 760.0) + _lattice(1900.0, 640.0, 640.0), 0.6),
					_layer(0.16, 2800.0, Color("#0a1117"), _masts(rng, 2800.0, 620.0, amber)),
				],
			}
		"pier":
			return {
				"top": Color("#070d15"), "low": Color("#26323e"), "glow": amber, "glow_at": Vector2(0.78, 0.6),
				"horizon": 0.64, "sea": Color("#0c1b24"),
				"layers": [
					_layer(0.02, 2400.0, Color("#141e28"), _ship(1700.0, 412.0, 700.0, rng, amber)),
					_layer(0.08, 2600.0, Color("#0f171f"), _cranes(rng, 2600.0, 460.0, 3, 330.0) + _lighthouse(300.0, 440.0, amber)),
					_layer(0.18, 2800.0, Color("#090f14"), _waves(rng, 2800.0, 560.0)),
				],
			}
		# Chapter three: open sea, the ship's hold, the Kelder platforms and the lab.
		"ship", "storm":
			var storm := name == "storm"
			return {
				"top": Color("#081119") if storm else Color("#132232"), "low": Color("#2c3a44") if storm else Color("#6a5a55"),
				"glow": Color("#cfe2ea") if storm else amber, "glow_at": Vector2(0.35, 0.35) if storm else Vector2(0.8, 0.6),
				"horizon": 0.62, "sea": Color("#0d1f28") if storm else Color("#14303a"),
				"layers": [
					_layer(0.02, 2400.0, Color("#1b2731") if storm else Color("#2a3640"), _clouds(rng, 2400.0)),
					_layer(0.07, 2600.0, Color("#101b23"), _platform(1700.0, 420.0, 0.7, amber) + _waves(rng, 2600.0, 440.0)),
					_layer(0.18, 2800.0, Color("#09121a"), _waves(rng, 2800.0, 540.0 if storm else 570.0)),
				],
			}
		"hold":
			return {
				"top": Color("#070b10"), "low": Color("#1c2530"), "glow": amber, "glow_at": Vector2(0.5, 0.2),
				"horizon": 0.96,
				"layers": [
					_layer(0.03, 2400.0, Color("#121a22"), _ribs(2400.0, 70.0, 240.0)),
					_layer(0.1, 2600.0, Color("#0e151c"), _stacks(rng, 2600.0, 560.0, true)),
					_layer(0.2, 2800.0, Color("#080d12"), _pipe_rack(2800.0, 610.0)),
				],
			}
		"kelder":
			return {
				"top": Color("#0a1420"), "low": Color("#3a4652"), "glow": amber, "glow_at": Vector2(0.7, 0.55),
				"horizon": 0.66, "sea": Color("#0f222c"),
				"layers": [
					_layer(0.03, 2400.0, Color("#18232d"), _platform(600.0, 430.0, 0.8, amber) + _platform(1800.0, 440.0, 0.6, amber)),
					_layer(0.1, 2600.0, Color("#111a22"), _platform(1300.0, 560.0, 1.4, amber) + _cranes(rng, 2600.0, 470.0, 2, 260.0)),
					_layer(0.2, 2800.0, Color("#0a1117"), _waves(rng, 2800.0, 590.0)),
				],
			}
		"pipes":
			return {
				"top": Color("#0b121b"), "low": Color("#4a4448"), "glow": Color("#ff9a5a"), "glow_at": Vector2(0.4, 0.45),
				"horizon": 0.7, "sea": Color("#10202a"),
				"layers": [
					_layer(0.03, 2400.0, Color("#17212a"), _flare(900.0, 470.0, Color("#ffb45e")) + _platform(1800.0, 450.0, 0.7, amber)),
					_layer(0.1, 2600.0, Color("#10181f"), _pipe_rack(2600.0, 470.0)),
					_layer(0.2, 2800.0, Color("#0a1016"), _pipe_rack(2800.0, 600.0)),
				],
			}
		"rig":
			return {
				"top": Color("#091019"), "low": Color("#33404a"), "glow": Color("#ff9a5a"), "glow_at": Vector2(0.25, 0.5),
				"horizon": 0.68, "sea": Color("#0c1c25"),
				"layers": [
					_layer(0.03, 2400.0, Color("#16212b"), _flare(400.0, 470.0, Color("#ffb45e")) + _platform(1500.0, 450.0, 0.9, amber)),
					_layer(0.08, 2600.0, Color("#101920"), _lattice(1300.0, 620.0, 700.0), 0.6),
					_layer(0.18, 2800.0, Color("#0a1117"), _waves(rng, 2800.0, 580.0)),
				],
			}
		"lab", "chamber", "core":
			var violet := Color("#b49cff")
			var warm := name == "core"
			var heart := Color("#ffae66") if warm else violet
			return {
				"top": Color("#07080f"), "low": Color("#2a1d18") if warm else Color("#1d1a2c"), "glow": heart, "glow_at": Vector2(0.5, 0.45),
				"horizon": 0.97,
				"layers": [
					_layer(0.03, 2400.0, Color("#221712") if warm else Color("#15142a"), _rings(600.0, 300.0, 240.0, 3, heart) + _rings(1800.0, 320.0, 200.0, 2, heart)),
					_layer(0.1, 2600.0, Color("#170f0c") if warm else Color("#0f0f1e"), _panels(2600.0, 600.0, heart)),
					_layer(0.2, 2800.0, Color("#09090f"), _ribs(2800.0, 40.0, 420.0) if name == "chamber" else _pipe_rack(2800.0, 640.0)),
				],
			}
	# "coast": the freight line along the cliffs at dusk.
	return {
		"top": Color("#0f1d29"), "low": Color("#6a5850"), "glow": amber, "glow_at": Vector2(0.72, 0.6),
		"horizon": 0.64, "sea": Color("#173039"),
		"layers": [
			_layer(0.03, 2400.0, Color("#1d2a33"), _cliffs(rng, 2400.0, 420.0, 130.0, 6)),
			_layer(0.1, 2600.0, Color("#131d24"), _viaduct(0.0, 2600.0, 380.0) + _poles(2600.0, 380.0)),
			_layer(0.2, 2800.0, Color("#0b1318"), _cliffs(rng, 2800.0, 600.0, 90.0, 4)),
		],
	}


static func _layer(factor: float, width: float, color: Color, shapes: Array, rise: float = 0.35) -> Dictionary:
	return {"factor": factor, "width": width, "color": color, "shapes": shapes, "rise": rise}


## A ragged ridge of headlands along the whole layer.
static func _cliffs(rng: RandomNumberGenerator, width: float, base: float, height: float, peaks: int) -> Array:
	var points := PackedVector2Array([Vector2(0.0, VIEW.y + 200.0)])
	var steps := peaks * 6
	var start := 0.0
	for index in steps + 1:
		var x := width * index / steps
		var y := base - height * (0.35 + 0.65 * absf(sin(index * PI / 6.0 + rng.randf() * 0.6))) + rng.randf_range(-10.0, 10.0)
		if index == 0:
			start = y
		if index == steps:
			y = start
		points.append(Vector2(x, y))
	points.append(Vector2(width, VIEW.y + 200.0))
	return [["poly", points]]


static func _viaduct(from: float, to: float, deck: float) -> Array:
	var shapes: Array = [["rect", Rect2(from, deck, to - from, 14.0)]]
	var x := from + 40.0
	while x < to:
		# Tapering piers under the deck, with a brace between each pair.
		shapes.append(["poly", PackedVector2Array([Vector2(x - 10.0, deck + 14.0), Vector2(x + 10.0, deck + 14.0),
			Vector2(x + 18.0, VIEW.y + 100.0), Vector2(x - 18.0, VIEW.y + 100.0)])])
		shapes.append(["line", Vector2(x, deck + 60.0), Vector2(x + 120.0, deck + 60.0), 3.0])
		x += 120.0
	return shapes


static func _poles(width: float, deck: float) -> Array:
	var shapes: Array = []
	var x := 30.0
	while x < width:
		shapes.append(["line", Vector2(x, deck), Vector2(x, deck - 46.0), 3.0])
		shapes.append(["line", Vector2(x - 12.0, deck - 40.0), Vector2(x + 12.0, deck - 40.0), 2.0])
		x += 180.0
	shapes.append(["line", Vector2(0.0, deck - 38.0), Vector2(width, deck - 38.0), 1.0])
	return shapes


static func _truss(from: float, to: float, deck: float) -> Array:
	var shapes: Array = [["rect", Rect2(from, deck, to - from, 18.0)], ["line", Vector2(from, deck - 60.0), Vector2(to, deck - 60.0), 5.0]]
	var x := from
	while x < to:
		shapes.append(["line", Vector2(x, deck), Vector2(x + 60.0, deck - 60.0), 3.0])
		shapes.append(["line", Vector2(x + 60.0, deck - 60.0), Vector2(x + 120.0, deck), 3.0])
		shapes.append(["line", Vector2(x + 60.0, deck - 60.0), Vector2(x + 60.0, deck), 2.0])
		x += 120.0
	return shapes


static func _piers(width: float, deck: float, floor_y: float) -> Array:
	var shapes: Array = []
	var x := 200.0
	while x < width:
		shapes.append(["poly", PackedVector2Array([Vector2(x - 24.0, deck + 18.0), Vector2(x + 24.0, deck + 18.0),
			Vector2(x + 46.0, floor_y + 300.0), Vector2(x - 46.0, floor_y + 300.0)])])
		x += 520.0
	return shapes


## Ship-to-shore cranes: two legs, a cross beam, a long boom.
static func _cranes(rng: RandomNumberGenerator, width: float, base: float, count: int, height: float) -> Array:
	var shapes: Array = []
	for index in count:
		var x := width * (index + 0.3 + rng.randf() * 0.4) / count
		var top := base - height
		shapes.append(["line", Vector2(x - 40.0, base + 80.0), Vector2(x - 26.0, top), 7.0])
		shapes.append(["line", Vector2(x + 40.0, base + 80.0), Vector2(x + 26.0, top), 7.0])
		shapes.append(["rect", Rect2(x - 70.0, top - 8.0, 220.0, 16.0)])
		shapes.append(["line", Vector2(x - 26.0, top), Vector2(x, top - 70.0), 4.0])
		shapes.append(["line", Vector2(x + 26.0, top), Vector2(x, top - 70.0), 4.0])
		shapes.append(["line", Vector2(x, top - 70.0), Vector2(x + 150.0, top - 6.0), 2.0])
		shapes.append(["rect", Rect2(x - 30.0, top + 8.0, 34.0, 22.0)])
		shapes.append(["line", Vector2(x + 90.0, top + 8.0), Vector2(x + 90.0, top + 90.0), 1.5])
	return shapes


static func _stacks(rng: RandomNumberGenerator, width: float, base: float, colourful: bool) -> Array:
	var shapes: Array = []
	var tints := [Color("#3b2a26"), Color("#22343a"), Color("#3a3524"), Color("#2b2d3a")]
	var x := 20.0
	while x < width:
		var length := rng.randf_range(90.0, 150.0)
		var tiers := rng.randi_range(1, 4)
		for tier in tiers:
			var box := Rect2(x, base - (tier + 1) * 34.0, length, 32.0)
			if colourful:
				shapes.append(["rect", box, tints[rng.randi() % tints.size()]])
			else:
				shapes.append(["rect", box])
		x += length + rng.randf_range(10.0, 60.0)
	shapes.append(["rect", Rect2(0.0, base, width, VIEW.y)])
	return shapes


static func _masts(rng: RandomNumberGenerator, width: float, base: float, lamp: Color) -> Array:
	var shapes: Array = []
	var x := rng.randf_range(80.0, 200.0)
	while x < width:
		var tall := rng.randf_range(150.0, 230.0)
		shapes.append(["line", Vector2(x, base), Vector2(x, base - tall), 4.0])
		shapes.append(["line", Vector2(x - 16.0, base - tall), Vector2(x + 16.0, base - tall), 4.0])
		shapes.append(["light", Vector2(x - 10.0, base - tall + 4.0), lamp])
		shapes.append(["light", Vector2(x + 10.0, base - tall + 4.0), lamp])
		x += rng.randf_range(380.0, 560.0)
	return shapes


static func _cars(rng: RandomNumberGenerator, width: float, base: float) -> Array:
	var shapes: Array = [["rect", Rect2(0.0, base, width, VIEW.y)]]
	var x := 0.0
	while x < width:
		var length := 160.0
		if rng.randf() < 0.75:
			shapes.append(["rect", Rect2(x, base - 58.0, length, 50.0)])
			shapes.append(["rect", Rect2(x + 20.0, base - 8.0, 14.0, 8.0)])
			shapes.append(["rect", Rect2(x + length - 34.0, base - 8.0, 14.0, 8.0)])
		x += length + 14.0
	return shapes


static func _ship(x: float, waterline: float, length: float, rng: RandomNumberGenerator, lamp: Color = Color("#ffb46e")) -> Array:
	var shapes: Array = []
	shapes.append(["poly", PackedVector2Array([Vector2(x, waterline - 60.0), Vector2(x + length, waterline - 70.0),
		Vector2(x + length - 50.0, waterline + 10.0), Vector2(x + 40.0, waterline + 10.0)])])
	shapes.append(["rect", Rect2(x + length - 170.0, waterline - 170.0, 100.0, 110.0)])
	shapes.append(["rect", Rect2(x + length - 150.0, waterline - 210.0, 30.0, 40.0)])
	var cx := x + 60.0
	while cx < x + length - 200.0:
		var tiers := rng.randi_range(1, 3)
		shapes.append(["rect", Rect2(cx, waterline - 60.0 - tiers * 26.0, 70.0, tiers * 26.0)])
		cx += 76.0
	for index in 5:
		shapes.append(["light", Vector2(x + length - 160.0 + index * 18.0, waterline - 150.0), lamp])
	return shapes


static func _lighthouse(x: float, base: float, lamp: Color) -> Array:
	return [
		["poly", PackedVector2Array([Vector2(x - 26.0, base), Vector2(x + 26.0, base), Vector2(x + 14.0, base - 190.0), Vector2(x - 14.0, base - 190.0)])],
		["rect", Rect2(x - 20.0, base - 216.0, 40.0, 26.0)],
		["light", Vector2(x, base - 204.0), lamp],
		["rect", Rect2(x - 200.0, base, 420.0, 30.0)],
	]


static func _lattice(x: float, base: float, height: float) -> Array:
	var shapes: Array = []
	var top := base - height
	shapes.append(["line", Vector2(x - 60.0, base + 200.0), Vector2(x - 28.0, top), 6.0])
	shapes.append(["line", Vector2(x + 60.0, base + 200.0), Vector2(x + 28.0, top), 6.0])
	var y := base + 160.0
	var level := 0
	while y > top + 40.0:
		var half := lerpf(28.0, 60.0, clampf((y - top) / (base + 200.0 - top), 0.0, 1.0))
		shapes.append(["line", Vector2(x - half, y), Vector2(x + half, y - 70.0), 2.0])
		shapes.append(["line", Vector2(x + half, y), Vector2(x - half, y - 70.0), 2.0])
		if level % 3 == 0:
			shapes.append(["rect", Rect2(x - half - 20.0, y - 26.0, (half + 20.0) * 2.0, 26.0)])
			shapes.append(["light", Vector2(x - half, y - 14.0), Color("#8be9ff")])
		y -= 70.0
		level += 1
	shapes.append(["rect", Rect2(x - 70.0, top - 60.0, 140.0, 60.0)])
	shapes.append(["light", Vector2(x, top - 30.0), Color("#ffb46e")])
	return shapes


static func _clouds(rng: RandomNumberGenerator, width: float) -> Array:
	var shapes: Array = []
	for index in 9:
		var center := Vector2(rng.randf_range(0.0, width), rng.randf_range(80.0, 300.0))
		var points := PackedVector2Array()
		var stretch := rng.randf_range(120.0, 260.0)
		for step in 16:
			var angle := TAU * step / 16.0
			points.append(center + Vector2(cos(angle) * stretch, sin(angle) * stretch * 0.22))
		shapes.append(["poly", points])
	return shapes


## An offshore platform: a deck on splayed legs, a block of rooms and a derrick.
static func _platform(x: float, base: float, size: float, lamp: Color) -> Array:
	var shapes: Array = []
	var deck := base - 120.0 * size
	var half := 160.0 * size
	for leg in [-0.8, -0.3, 0.3, 0.8]:
		shapes.append(["line", Vector2(x + half * leg, deck), Vector2(x + half * leg * 1.15, base + 200.0), 8.0 * size])
	shapes.append(["line", Vector2(x - half * 0.9, deck + 60.0 * size), Vector2(x + half * 0.9, deck + 60.0 * size), 4.0 * size])
	shapes.append(["rect", Rect2(x - half, deck - 16.0 * size, half * 2.0, 16.0 * size)])
	shapes.append(["rect", Rect2(x - half * 0.7, deck - 70.0 * size, half * 0.8, 54.0 * size)])
	shapes.append(["rect", Rect2(x + half * 0.2, deck - 46.0 * size, half * 0.5, 30.0 * size)])
	shapes.append(["line", Vector2(x + half * 0.45, deck - 16.0 * size), Vector2(x + half * 0.55, deck - 190.0 * size), 3.0 * size])
	shapes.append(["line", Vector2(x + half * 0.75, deck - 16.0 * size), Vector2(x + half * 0.6, deck - 190.0 * size), 3.0 * size])
	for index in 4:
		shapes.append(["light", Vector2(x - half * 0.6 + index * half * 0.3, deck - 40.0 * size), lamp])
	shapes.append(["light", Vector2(x + half * 0.57, deck - 192.0 * size), Color("#ff6a4a")])
	return shapes


## A flare stack with its flame.
static func _flare(x: float, base: float, flame: Color) -> Array:
	return [
		["line", Vector2(x, base + 100.0), Vector2(x, base - 260.0), 6.0],
		["line", Vector2(x - 30.0, base + 100.0), Vector2(x - 6.0, base - 200.0), 2.0],
		["line", Vector2(x + 30.0, base + 100.0), Vector2(x + 6.0, base - 200.0), 2.0],
		["poly", PackedVector2Array([Vector2(x - 12.0, base - 262.0), Vector2(x + 14.0, base - 262.0), Vector2(x + 26.0, base - 300.0),
			Vector2(x + 6.0, base - 340.0), Vector2(x - 4.0, base - 310.0), Vector2(x - 18.0, base - 300.0)]), flame],
		["light", Vector2(x, base - 290.0), flame],
	]


## Rows of pipes on trestles.
static func _pipe_rack(width: float, base: float) -> Array:
	var shapes: Array = []
	for row in 4:
		var y := base - row * 36.0
		shapes.append(["line", Vector2(0.0, y), Vector2(width, y), 10.0 - row * 1.5])
	var x := 40.0
	while x < width:
		shapes.append(["line", Vector2(x, base + 60.0), Vector2(x, base - 150.0), 5.0])
		shapes.append(["line", Vector2(x - 30.0, base - 150.0), Vector2(x + 30.0, base - 150.0), 4.0])
		x += 260.0
	shapes.append(["rect", Rect2(0.0, base + 60.0, width, VIEW.y)])
	return shapes


## The frames of a hull or a hall: tall beams, a cross beam, a lamp between.
static func _ribs(width: float, top: float, spacing: float) -> Array:
	var shapes: Array = []
	var x := 30.0
	while x < width:
		shapes.append(["line", Vector2(x, top), Vector2(x, VIEW.y + 50.0), 10.0])
		shapes.append(["line", Vector2(x, top + 40.0), Vector2(x + spacing, top + 40.0), 4.0])
		shapes.append(["light", Vector2(x + spacing * 0.5, top + 60.0), Color("#ffcf8a")])
		x += spacing
	shapes.append(["rect", Rect2(0.0, top - 30.0, width, 30.0)])
	return shapes


## Gravity coils seen at an angle: narrow upright ellipses of short segments.
static func _rings(x: float, center_y: float, radius: float, count: int, lamp: Color) -> Array:
	var shapes: Array = []
	for ring in count:
		var r := radius * (1.0 - ring * 0.18)
		var steps := 28
		for step in steps:
			var a := TAU * step / steps
			var b := TAU * (step + 1) / steps
			shapes.append(["line", Vector2(x + cos(a) * r * 0.35, center_y + sin(a) * r),
				Vector2(x + cos(b) * r * 0.35, center_y + sin(b) * r), 6.0 - ring])
		shapes.append(["light", Vector2(x, center_y - r), lamp])
	return shapes


## Wall panels with lit observation windows.
static func _panels(width: float, base: float, lamp: Color) -> Array:
	var shapes: Array = []
	var x := 0.0
	while x < width:
		shapes.append(["rect", Rect2(x + 10.0, base - 260.0, 180.0, 220.0)])
		shapes.append(["rect", Rect2(x + 30.0, base - 230.0, 140.0, 70.0), Color(lamp.darkened(0.75), 1.0)])
		shapes.append(["light", Vector2(x + 100.0, base - 30.0), lamp])
		x += 200.0
	shapes.append(["rect", Rect2(0.0, base, width, VIEW.y)])
	return shapes


static func _waves(rng: RandomNumberGenerator, width: float, base: float) -> Array:
	var points := PackedVector2Array([Vector2(0.0, VIEW.y + 200.0)])
	var steps := int(width / 60.0)
	var start := base
	for index in steps + 1:
		var y := base + sin(index * 0.9) * 12.0 + rng.randf_range(-6.0, 6.0)
		if index == 0:
			start = y
		if index == steps:
			y = start
		points.append(Vector2(width * index / steps, y))
	points.append(Vector2(width, VIEW.y + 200.0))
	return [["poly", points]]
