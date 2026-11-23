extends Control

## The right half of the New Game page: the chosen chapter's boss on a lit
## pedestal in front of its home, idling the way a unit does in an armory
## screen. A chapter that cannot be started yet shows its boss as a silhouette
## behind a lock.
##
## The bosses are drawn in code. A painting replaces one when it is added:
##   res://assets/showcase/chapter1.png        the boss, transparent background
##   res://assets/showcase/chapter1_glow.png   (optional) its lights alone, same size
##   res://assets/showcase/chapter1_back.jpg   (optional) the background
## chapter2…, chapter3… for the others. The idle motion is added in code.

const Skyline = preload("res://scripts/skyline.gd")
const ART_DIR := "res://assets/showcase/"
const SIL := Color("#06090c")
const RIM := Color("#9fd8e8")
const ICE := Color("#84ebff")
const AMBER := Color("#ffb46e")
const RED := Color("#ff7251")
const STEEL := Color("#2a3238")
const PLATE := Color("#8d979b")
const BLACK := Color("#10181d")
## Accent per chapter: pedestal rim, frame and particles.
const ACCENTS := [Color("#ffb46e"), Color("#8be9ff"), Color("#ffae66")]
const LOCKED_ACCENT := Color("#6f7f88")

var chapter := 0
var locked := false
var clock := 0.0
## 0 right after a switch, 1 once the new boss has settled in.
var appear := 1.0
## 0 normal colours, 1 rim pass, 2 silhouette pass.
var paint_mode := 0
var art_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func show_chapter(index: int, is_locked: bool) -> void:
	if index == chapter and is_locked == locked:
		return
	chapter = index
	locked = is_locked
	appear = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	clock += delta
	appear = minf(1.0, appear + delta / 0.45)
	queue_redraw()


func _art(name: String) -> Texture2D:
	if not art_cache.has(name):
		var found: Texture2D = null
		for extension: String in [".png", ".jpg", ".webp"]:
			var path: String = ART_DIR + name + extension
			if ResourceLoader.exists(path):
				found = load(path)
				break
		art_cache[name] = found
	return art_cache[name]


func _accent() -> Color:
	return LOCKED_ACCENT if locked else ACCENTS[clampi(chapter, 0, ACCENTS.size() - 1)]


## Solid parts: real colours, the rim colour, or the silhouette.
func _c(color: Color) -> Color:
	match paint_mode:
		1:
			return Color(RIM, 0.55 * color.a)
		2:
			return Color(SIL, color.a)
	return color


## Lights only exist in the normal pass.
func _light(color: Color) -> Color:
	return color if paint_mode == 0 else Color(0, 0, 0, 0)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_draw_backdrop(rect)
	_draw_pedestal(rect)
	var settle := ease(appear, -2.2)
	var feet := Vector2(size.x * 0.54 + (1.0 - settle) * 40.0, size.y * 0.845)
	var figure := _art("chapter%d" % (chapter + 1))
	if locked:
		paint_mode = 1
		_draw_boss(feet + Vector2(-3.0, -2.0), settle, figure)
		paint_mode = 2
		_draw_boss(feet, settle, figure)
		paint_mode = 0
	else:
		_draw_boss(feet, settle, figure)
	_draw_overlay(rect)
	if locked:
		_draw_lock(Vector2(feet.x, size.y * 0.93))
	if appear < 1.0:
		draw_rect(rect, Color(0.004, 0.012, 0.02, 0.7 * (1.0 - settle)))


func _draw_boss(feet: Vector2, settle: float, figure: Texture2D) -> void:
	if figure != null:
		_draw_painting(feet, figure, _art("chapter%d_glow" % (chapter + 1)))
		return
	match chapter:
		0:
			_draw_foreman(feet, 1.7)
		1:
			_draw_dispatcher(Vector2(feet.x, size.y * 0.06), 1.22)
		_:
			_draw_echo(feet, 2.5)


# ------------------------------------------------------------------ backdrops


func _draw_backdrop(rect: Rect2) -> void:
	var back := _art("chapter%d_back" % (chapter + 1))
	if back != null:
		# A slow push in on the painting.
		var zoom := 1.06 + 0.03 * sin(clock * 0.12)
		var fit := maxf(rect.size.x / back.get_width(), rect.size.y / back.get_height()) * zoom
		var shown := Vector2(back.get_width(), back.get_height()) * fit
		var drift := Vector2(sin(clock * 0.09) * 14.0, cos(clock * 0.07) * 8.0)
		draw_texture_rect(back, Rect2(rect.get_center() - shown * 0.5 + drift, shown), false)
	elif chapter == 0:
		_draw_wheel_hall(rect)
	else:
		var theme := "pier" if chapter == 1 else "core"
		Skyline.paint(self, rect, theme, Vector2(576.0 + clock * 9.0, 342.0 + sin(clock * 0.2) * 10.0), 1.0)
	# Grade it down so the boss reads in front of it.
	draw_rect(rect, Color(0.01, 0.02, 0.03, 0.62 if locked else (0.55 if chapter == 2 else 0.38)))
	var accent := _accent()
	for ring in 4:
		draw_circle(Vector2(rect.size.x * 0.54, rect.size.y * 0.55), rect.size.y * (0.18 + ring * 0.11), Color(accent, 0.025))
	# Vignette: darker toward every edge, darkest at the left where the menu sits.
	var dark := Color(0.004, 0.012, 0.02, 0.95)
	var clear := Color(dark, 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(150, 0), Vector2(150, rect.size.y), Vector2(0, rect.size.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(0, rect.size.y - 120), Vector2(rect.size.x, rect.size.y - 120), rect.size, Vector2(0, rect.size.y)]),
		PackedColorArray([clear, clear, dark, dark]))
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), Vector2(rect.size.x, 90), Vector2(0, 90)]),
		PackedColorArray([Color(dark, 0.7), Color(dark, 0.7), clear, clear]))


## Chapter one's home: the furnace hall behind the great wheel, turning slowly.
func _draw_wheel_hall(rect: Rect2) -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)]),
		PackedColorArray([Color("#0b0a0b"), Color("#0b0a0b"), Color("#33190d"), Color("#33190d")]))
	var glow := Vector2(rect.size.x * 0.55, rect.size.y * 1.02)
	for ring in 6:
		draw_circle(glow, 90.0 + ring * 70.0, Color(1.0, 0.45, 0.15, 0.06))
	var hub := Vector2(rect.size.x * 0.6, rect.size.y * 0.42)
	var radius := rect.size.y * 0.42
	var turn := clock * 0.09
	var iron := Color("#1a1716")
	draw_arc(hub, radius, 0.0, TAU, 96, iron, 34.0, true)
	draw_arc(hub, radius + 15.0, 0.0, TAU, 96, Color(1.0, 0.55, 0.25, 0.18), 2.0, true)
	draw_arc(hub, radius - 17.0, 0.0, TAU, 96, Color(1.0, 0.55, 0.25, 0.1), 1.5, true)
	for spoke in 12:
		var angle := turn + TAU * spoke / 12.0
		draw_line(hub + Vector2.from_angle(angle) * 40.0, hub + Vector2.from_angle(angle) * (radius - 14.0), iron, 12.0, true)
		# A lamp on every other spoke, catching the furnace light.
		if spoke % 2 == 0:
			draw_circle(hub + Vector2.from_angle(angle) * (radius - 40.0), 4.0, Color(1.0, 0.6, 0.3, 0.35))
	draw_circle(hub, 52.0, iron)
	draw_circle(hub, 22.0, Color(1.0, 0.5, 0.2, 0.25 + 0.1 * sin(clock * 1.3)))
	# Sparks rising out of the furnace.
	for spark in 18:
		var lane := fposmod(spark * 0.618034, 1.0)
		var rise := fposmod(clock * (0.07 + 0.05 * fposmod(spark * 0.37, 1.0)) + spark * 0.13, 1.0)
		var point := Vector2(rect.size.x * (0.1 + lane * 0.85) + sin(clock + spark) * 8.0, rect.size.y * (1.0 - rise))
		draw_circle(point, 1.6 + 1.2 * fposmod(spark * 0.53, 1.0), Color(1.0, 0.65, 0.3, 0.6 * (1.0 - rise)))


func _draw_pedestal(rect: Rect2) -> void:
	var accent := _accent()
	var center := Vector2(rect.size.x * 0.54, rect.size.y * 0.845)
	# A cone of light from above onto the pedestal.
	var top := Color(accent, 0.0)
	var low := Color(accent, 0.09 if not locked else 0.04)
	draw_polygon(PackedVector2Array([center + Vector2(-70.0, -rect.size.y * 0.85), center + Vector2(70.0, -rect.size.y * 0.85),
		center + Vector2(230.0, 0.0), center + Vector2(-230.0, 0.0)]), PackedColorArray([top, top, low, low]))
	draw_set_transform(center, 0.0, Vector2(1.0, 0.17))
	draw_circle(Vector2.ZERO, 250.0, Color(0.02, 0.03, 0.04, 0.92))
	draw_circle(Vector2.ZERO, 236.0, Color(accent, 0.06))
	var spin := clock * 0.35
	draw_arc(Vector2.ZERO, 236.0, 0.0, TAU, 80, Color(accent, 0.55), 3.0, true)
	draw_arc(Vector2.ZERO, 198.0, spin, spin + 2.4, 40, Color(accent, 0.4), 2.0, true)
	draw_arc(Vector2.ZERO, 198.0, spin + PI, spin + PI + 2.4, 40, Color(accent, 0.4), 2.0, true)
	draw_arc(Vector2.ZERO, 160.0, -spin * 1.6, -spin * 1.6 + 1.2, 30, Color(accent, 0.3), 1.5, true)
	draw_set_transform(Vector2.ZERO)


func _draw_overlay(rect: Rect2) -> void:
	var accent := _accent()
	# Faint scanlines, and a band of light that sweeps across now and then.
	for y in range(0, int(rect.size.y), 4):
		draw_line(Vector2(0, y), Vector2(rect.size.x, y), Color(0, 0, 0, 0.07), 1.0)
	var sweep := fposmod(clock / 6.5, 1.0) * 1.8 - 0.4
	if sweep > -0.2 and sweep < 1.2:
		var x := sweep * rect.size.x
		draw_polygon(PackedVector2Array([Vector2(x - 40.0, 0), Vector2(x + 20.0, 0), Vector2(x - 120.0, rect.size.y), Vector2(x - 180.0, rect.size.y)]),
			PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.0)]))
	# Corner brackets, as on a display.
	var inset := 22.0
	var arm := 34.0
	var corners := [Vector2(inset + 40.0, inset), Vector2(rect.size.x - inset, inset), Vector2(rect.size.x - inset, rect.size.y - inset), Vector2(inset + 40.0, rect.size.y - inset)]
	var dirs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		var corner: Vector2 = corners[i]
		var dir: Vector2 = dirs[i]
		draw_line(corner, corner + Vector2(dir.x * arm, 0.0), Color(accent, 0.7), 2.0)
		draw_line(corner, corner + Vector2(0.0, dir.y * arm), Color(accent, 0.7), 2.0)
	# Motes drifting up through the light.
	for mote in 22:
		var lane := fposmod(mote * 0.618034 + 0.2, 1.0)
		var rise := fposmod(clock * (0.03 + 0.03 * fposmod(mote * 0.41, 1.0)) + mote * 0.17, 1.0)
		var point := Vector2(rect.size.x * (0.25 + lane * 0.6) + sin(clock * 0.7 + mote) * 10.0, rect.size.y * (0.9 - rise * 0.8))
		draw_circle(point, 1.4, Color(accent, 0.4 * sin(rise * PI)))


func _draw_lock(at: Vector2) -> void:
	var tint := Color(LOCKED_ACCENT, 0.9)
	draw_arc(at + Vector2(0.0, -16.0), 11.0, PI, TAU, 20, tint, 4.0, true)
	draw_line(at + Vector2(-11.0, -16.0), at + Vector2(-11.0, -8.0), tint, 4.0)
	draw_line(at + Vector2(11.0, -16.0), at + Vector2(11.0, -8.0), tint, 4.0)
	draw_rect(Rect2(at + Vector2(-17.0, -9.0), Vector2(34.0, 24.0)), tint)
	draw_circle(at + Vector2(0.0, 1.0), 3.5, Color("#0b1116"))


# ------------------------------------------------------------------ a painting


func _draw_painting(feet: Vector2, figure: Texture2D, glow: Texture2D) -> void:
	var box := Vector2(size.x * 0.82, size.y * 0.74)
	var fit := minf(box.x / figure.get_width(), box.y / figure.get_height())
	var shown := Vector2(figure.get_width(), figure.get_height()) * fit
	var breath := sin(clock * TAU / 3.6)
	var stretch := Vector2(1.0 - 0.004 * breath, 1.0 + 0.009 * breath)
	var bob := Vector2(0.0, -2.0 - 2.0 * breath)
	draw_set_transform(feet + bob, 0.0, stretch)
	var area := Rect2(Vector2(-shown.x * 0.5, -shown.y), shown)
	match paint_mode:
		0:
			draw_texture_rect(figure, area, false)
			if glow != null:
				draw_texture_rect(glow, area, false, Color(1, 1, 1, 0.55 + 0.35 * sin(clock * 2.4)))
		1:
			draw_texture_rect(figure, area, false, Color(RIM, 0.5))
		2:
			draw_texture_rect(figure, area, false, SIL)
	draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ 포어맨


## The Foreman idling on its tracks: the engine trembles, its body rises and
## settles, the visor lamp scans, the radiator glows and the stacks smoke. Now
## and then it revs.
func _draw_foreman(feet: Vector2, scale: float) -> void:
	var rev_phase := fposmod(clock, 7.0)
	var rev := smoothstep(0.0, 0.15, rev_phase) * (1.0 - smoothstep(0.6, 1.0, rev_phase))
	var tremble := sin(clock * 37.0) * (0.6 + 2.2 * rev)
	var breath := sin(clock * TAU / 3.2) * 2.5
	# Smoke goes behind the machine.
	if paint_mode == 0:
		for puff in 7:
			var phase := fposmod(clock * (0.32 + 0.25 * rev) + puff / 7.0, 1.0)
			var stack := Vector2(58.0 + (puff % 2) * 16.0, -196.0)
			var point := feet + Vector2((stack.x + sin(puff * 2.1 + clock) * 7.0 + phase * 26.0) * scale, (stack.y - phase * 95.0 + breath) * scale)
			draw_circle(point, (6.0 + phase * 18.0) * scale, Color(0.55, 0.52, 0.5, (1.0 - phase) * (0.16 + 0.1 * rev)))
	# Facing left, toward the menu: the drawing is mirrored.
	draw_set_transform(feet + Vector2(tremble, 0.0), 0.0, Vector2(-scale, scale))
	_foreman_tracks()
	draw_set_transform(feet + Vector2(tremble, breath * scale), 0.0, Vector2(-scale, scale))
	_foreman_body(rev)
	draw_set_transform(Vector2.ZERO)


func _foreman_tracks() -> void:
	var half := 96.0
	draw_rect(Rect2(-half, -40.0, half * 2.0, 40.0), _c(BLACK))
	draw_circle(Vector2(-half, -20.0), 20.0, _c(BLACK))
	draw_circle(Vector2(half, -20.0), 20.0, _c(BLACK))
	for wheel in 7:
		var x := -half + 12.0 + wheel * 28.0
		draw_circle(Vector2(x, -18.0), 12.0, _c(Color("#1c2830")))
		draw_arc(Vector2(x, -18.0), 12.0, 0.0, TAU, 18, _c(PLATE.darkened(0.45)), 1.5, true)
		draw_circle(Vector2(x, -18.0), 3.0, _c(PLATE.darkened(0.2)))
	for tread in 16:
		var x := -half - 8.0 + tread * 13.0
		draw_line(Vector2(x, -40.0), Vector2(x + 4.0, -36.0), _c(PLATE.darkened(0.5)), 2.0)
	draw_line(Vector2(-half, -40.0), Vector2(half, -40.0), _c(PLATE.darkened(0.3)), 2.0)


func _foreman_body(rev: float) -> void:
	var lamp_glow := 0.5 + 0.5 * sin(clock * 3.0)
	# Hull and shoulder.
	draw_colored_polygon(PackedVector2Array([Vector2(-62, -40), Vector2(-70, -162), Vector2(-24, -190), Vector2(48, -182), Vector2(66, -40)]), _c(STEEL))
	draw_polyline(PackedVector2Array([Vector2(-70, -162), Vector2(-24, -190), Vector2(48, -182)]), _c(PLATE), 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -150), Vector2(-14, -168), Vector2(30, -162), Vector2(34, -96), Vector2(-36, -92)]), _c(STEEL.lightened(0.06)))
	# Hazard band.
	draw_rect(Rect2(-56.0, -72.0, 112.0, 10.0), _c(BLACK))
	for stripe in range(-52, 50, 14):
		draw_line(Vector2(stripe, -63.0), Vector2(stripe + 8, -72.0), _c(AMBER.darkened(0.25)), 3.0, true)
	# The heavy plate it leads with, ribbed.
	draw_colored_polygon(PackedVector2Array([Vector2(48, -170), Vector2(88, -154), Vector2(92, -56), Vector2(64, -44)]), _c(PLATE.darkened(0.1)))
	for rib in 6:
		draw_line(Vector2(56, -150.0 + rib * 18.0), Vector2(89, -142.0 + rib * 17.0), _c(STEEL), 3.0)
	# Radiator fins on its back, the heat climbing through them.
	for fin in 6:
		var heat := 0.5 + 0.5 * sin(clock * 2.6 - fin * 0.8)
		draw_rect(Rect2(-84.0, -150.0 + fin * 18.0, 15.0, 12.0), _c(Color("#1d262c")))
		draw_rect(Rect2(-82.0, -146.0 + fin * 18.0, 11.0, 4.0), _light(Color(1.0, 0.45 + 0.2 * heat, 0.2, 0.25 + 0.45 * heat * (0.6 + rev))))
	# Two exhaust stacks.
	for stack in [58.0, 74.0]:
		draw_rect(Rect2(-stack - 5.0, -200.0, 10.0, 28.0), _c(Color("#232b30")))
		draw_rect(Rect2(-stack - 6.0, -204.0, 12.0, 5.0), _c(PLATE.darkened(0.3)))
	# Head: a hard hat over a visor slit with a scanning lamp.
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -186), Vector2(-24, -216), Vector2(20, -220), Vector2(38, -200), Vector2(34, -182)]), _c(Color("#39444a")))
	draw_rect(Rect2(-34.0, -192.0, 76.0, 8.0), _c(AMBER.darkened(0.2)))
	draw_rect(Rect2(-2.0, -208.0, 36.0, 8.0), _c(BLACK))
	var scan := 15.0 + sin(clock * 1.7) * 12.0
	draw_rect(Rect2(scan - 5.0, -206.0, 10.0, 4.0), _light(Color("#fff0d0") if rev > 0.5 else AMBER))
	draw_circle(Vector2(scan, -204.0), 9.0, _light(Color(AMBER, 0.25)))
	# Chest core.
	var core := Vector2(6.0, -118.0)
	draw_circle(core, 20.0, _c(BLACK))
	draw_circle(core, 16.0, _c(Color("#3e4b4d")))
	draw_arc(core, 16.0, 0.0, TAU, 30, _c(Color("#b2a19a")), 1.5, true)
	draw_circle(core, 10.0, _light(Color(AMBER, 0.35 + 0.35 * lamp_glow)))
	draw_circle(core, 26.0 + 6.0 * lamp_glow, _light(Color(AMBER, 0.08)))


# ------------------------------------------------------------------ 디스패처


## The Dispatcher's cab on its overhead rail: it sways a little on its cables,
## the hung container sways a beat later, the windows flicker with traffic and
## the signal mast beside it cycles its lamps. `top` is the rail.
func _draw_dispatcher(top: Vector2, scale: float) -> void:
	var drift := sin(clock * 0.4) * 14.0
	var sway := sin(clock * TAU / 4.6) * 0.045
	var lag := sin(clock * TAU / 4.6 - 0.8) * 0.07
	# Signal mast at the side.
	var mast := Vector2(top.x - 230.0, top.y)
	draw_rect(Rect2(mast.x - 9.0, mast.y + 40.0, 18.0, size.y * 0.8 - mast.y - 40.0), _c(STEEL))
	draw_rect(Rect2(mast.x - 20.0, mast.y + 70.0, 40.0, 34.0), _c(STEEL.lightened(0.05)))
	for lamp in 4:
		var on := int(clock * 1.6 + lamp) % 4 == 0
		draw_circle(Vector2(mast.x, mast.y + 130.0 + lamp * 30.0), 7.0, _c(Color("#5b4a44")))
		if on:
			draw_circle(Vector2(mast.x, mast.y + 130.0 + lamp * 30.0), 7.0, _light(Color("#ff9b5c")))
			draw_circle(Vector2(mast.x, mast.y + 130.0 + lamp * 30.0), 16.0, _light(Color(1.0, 0.6, 0.35, 0.18)))
	# The rail.
	draw_rect(Rect2(0.0, top.y - 12.0, size.x, 22.0), _c(BLACK))
	draw_line(Vector2(0.0, top.y - 11.0), Vector2(size.x, top.y - 11.0), _c(PLATE.darkened(0.2)), 2.0)
	var trolley := Vector2(top.x + drift, top.y)
	draw_rect(Rect2(trolley.x - 60.0, trolley.y - 20.0, 120.0, 30.0), _c(STEEL))
	for wheel in [-38.0, 38.0]:
		draw_circle(Vector2(trolley.x + wheel, trolley.y - 12.0), 8.0, _c(Color("#1c2830")))
	# Everything below hangs from the trolley and sways around it.
	draw_set_transform(trolley, sway, Vector2(scale, scale))
	_dispatcher_cab(lag)
	draw_set_transform(Vector2.ZERO)


## In the cab's own frame: the trolley at the origin, the roof 130 below.
func _dispatcher_cab(lag: float) -> void:
	var roof := 130.0
	var half := 120.0
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 40.0, 8.0), Vector2(side * 80.0, roof), _c(BLACK), 3.0)
	draw_rect(Rect2(-half, roof, half * 2.0, 16.0), _c(PLATE.darkened(0.15)))
	draw_line(Vector2(-half, roof), Vector2(half, roof), _c(PLATE.lightened(0.25)), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-half + 10.0, roof + 16.0), Vector2(half - 10.0, roof + 16.0),
		Vector2(half - 34.0, roof + 64.0), Vector2(-half + 34.0, roof + 64.0)]), _c(STEEL))
	for window in 5:
		var wx := -86.0 + window * 36.0
		var lit := 0.35 + 0.3 * sin(clock * (2.0 + window * 0.7) + window * 1.9)
		draw_rect(Rect2(wx, roof + 24.0, 28.0, 20.0), _c(Color("#1c2228")))
		draw_rect(Rect2(wx, roof + 24.0, 28.0, 20.0), _light(Color("#ffcf8a", lit)))
		# Traffic scrolling past behind the glass.
		var bar := fposmod(clock * 18.0 + window * 7.0, 20.0)
		draw_rect(Rect2(wx + 3.0, roof + 25.0 + bar * 0.9, 22.0, 2.0), _light(Color("#fff3d6", 0.5)))
	# Signal field around the core, faint.
	var core := Vector2(0.0, roof + 92.0)
	draw_line(Vector2(0.0, roof + 64.0), core, _c(BLACK), 6.0)
	draw_circle(core, 24.0, _c(BLACK))
	draw_circle(core, 18.0, _c(Color("#3e4b4d")))
	draw_circle(core, 11.0, _light(Color(AMBER, 0.5 + 0.3 * sin(clock * 3.2))))
	draw_circle(core, 30.0 + 6.0 * sin(clock * 1.6), _light(Color("#ff9b5c", 0.08)))
	# The hung container, one beat behind the cab.
	var hook := Vector2(0.0, roof + 64.0)
	var held := Transform2D(lag, hook)
	var corners := [Vector2(-100, 150), Vector2(100, 150), Vector2(100, 250), Vector2(-100, 250)]
	var cable_top := [Vector2(-70.0, roof + 60.0), Vector2(70.0, roof + 60.0)]
	for i in 2:
		var end: Vector2 = held * Vector2(-70.0 + i * 140.0, 150.0 - 64.0)
		draw_line(cable_top[i], end, _c(BLACK), 3.0)
	var box := PackedVector2Array()
	for corner: Vector2 in corners:
		box.append(held * (corner - Vector2(0.0, 64.0)))
	draw_colored_polygon(box, _c(Color("#2f5568")))
	for rib in 7:
		var a: Vector2 = held * Vector2(-88.0 + rib * 29.0, 92.0)
		var b: Vector2 = held * Vector2(-88.0 + rib * 29.0, 180.0)
		draw_line(a, b, _c(Color("#21404f")), 4.0)
	var blink := int(clock * 2.0) % 2 == 0
	var lamp: Vector2 = held * Vector2(0.0, 100.0)
	draw_circle(lamp, 6.0, _c(Color("#3a4c55")))
	if blink:
		draw_circle(lamp, 6.0, _light(ICE))
		draw_circle(lamp, 16.0, _light(Color(ICE, 0.2)))


# ------------------------------------------------------------------ 에코


## Echo at rest: breathing, weight shifting from foot to foot, the chest disc
## drinking in motes of light, a glint running along the visor. Every so often
## he lifts a hand, gathers the light into the palm and closes it. A faint
## amber afterimage follows a moment behind, the echo of his name.
func _draw_echo(feet: Vector2, scale: float) -> void:
	if paint_mode == 0:
		draw_set_transform(feet + Vector2(-12.0, -2.0), 0.0, Vector2(-scale, scale))
		_echo_figure(clock - 0.45, true)
		draw_set_transform(Vector2.ZERO)
	draw_set_transform(feet, 0.0, Vector2(-scale, scale))
	_echo_figure(clock, false)
	draw_set_transform(Vector2.ZERO)
	if paint_mode == 0:
		# Motes drawn into the chest disc from all around. He is mirrored, so
		# the disc is left of centre.
		var disc := feet + Vector2(-8.0, -114.0 + _echo_breath(clock)) * scale
		for mote in 12:
			var phase := fposmod(clock * 0.32 + mote / 12.0, 1.0)
			var angle := mote * 2.399 + clock * 0.2
			var reach := (1.0 - phase) * 170.0 + 14.0
			var point := disc + Vector2.from_angle(angle) * reach * Vector2(1.0, 0.75)
			draw_circle(point, 1.3 + phase * 1.2, Color(AMBER, 0.5 * phase))


func _echo_breath(time: float) -> float:
	return sin(time * TAU / 3.6) * 1.6


## How far the palm gesture has come, 0 to 1 and back, once every nine seconds.
func _echo_gesture(time: float) -> float:
	var phase := fposmod(time, 9.0)
	return smoothstep(4.5, 5.4, phase) * (1.0 - smoothstep(7.4, 8.4, phase))


## Drawn facing right in Echo's own units (feet at the origin, about 165 tall);
## the transform mirrors him to face left. The ghost is the afterimage: every
## part in faint amber.
func _echo_figure(time: float, ghost: bool) -> void:
	var col := func(color: Color) -> Color: return Color(AMBER, 0.07) if ghost else _c(color)
	var suit: Color = col.call(Color("#363c45"))
	var under: Color = col.call(Color("#1c2026"))
	var plate: Color = col.call(Color("#5d6772"))
	var edge: Color = col.call(Color("#aab7c0"))
	var trim: Color = col.call(AMBER)
	var breath := _echo_breath(time)
	var shift := sin(time * TAU / 7.5) * 2.0
	var lift := _echo_gesture(time)
	var hip := Vector2(shift, -78.0)
	var neck := hip + Vector2(-shift * 0.4 + 2.0, -60.0 + breath)
	var chest := hip + Vector2(-shift * 0.3 + 2.0, -34.0 + breath * 0.6)
	var head := neck + Vector2(3.0, -14.0 + breath * 0.2)
	# Far leg and far arm, behind the body and a shade darker.
	_echo_leg(hip + Vector2(-5.0, 2.0), Vector2(-10.0 + shift * 0.2, 0.0), under, suit)
	var far_shoulder := neck + Vector2(-9.0, 7.0)
	_echo_arm(far_shoulder, far_shoulder + Vector2(-5.0, 47.0 + breath * 0.4), under, suit)
	# Back unit, the store for what he catches, and its two cables.
	var pack := Rect2(neck.x - 31.0, neck.y + 6.0, 15.0, 42.0)
	draw_rect(pack, under)
	draw_rect(Rect2(pack.position + Vector2(3.0, 7.0), Vector2(9.0, 3.0)), trim if ghost else _light(Color(AMBER, 0.55)))
	for cable in 2:
		var sway := sin(time * 1.3 + cable) * 3.0
		draw_line(Vector2(pack.position.x + 4.0 + cable * 6.0, pack.end.y), Vector2(hip.x - 15.0 + cable * 4.0 + sway, hip.y + 16.0), under, 2.0, true)
	# Torso: a tapered chest, a lighter breastplate, the shoulder line, the belt.
	draw_colored_polygon(PackedVector2Array([hip + Vector2(-11.0, 3.0), hip + Vector2(12.0, 3.0), chest + Vector2(17.0, -4.0),
		neck + Vector2(21.0, 9.0), neck + Vector2(-17.0, 9.0), chest + Vector2(-14.0, -2.0)]), suit)
	draw_colored_polygon(PackedVector2Array([chest + Vector2(-3.0, -20.0), chest + Vector2(16.0, -18.0),
		chest + Vector2(13.0, 7.0), chest + Vector2(-1.0, 9.0)]), plate)
	draw_line(neck + Vector2(-17.0, 9.0), neck + Vector2(21.0, 9.0), edge, 1.5)
	draw_rect(Rect2(hip.x - 12.0, hip.y - 3.0, 25.0, 6.0), under)
	draw_line(Vector2(hip.x - 12.0, hip.y), Vector2(hip.x + 13.0, hip.y), trim, 2.0)
	_echo_leg(hip + Vector2(5.0, 2.0), Vector2(11.0 + shift * 0.3, 0.0), suit, plate)
	# The chest disc, drinking.
	var disc := chest + Vector2(7.0, -6.0)
	draw_circle(disc, 7.5, under)
	draw_arc(disc, 7.5, 0.0, TAU, 24, edge, 1.2, true)
	if not ghost:
		var pulse := 0.5 + 0.5 * sin(time * 2.6)
		draw_circle(disc, 4.8, _c(Color("#3b2f28")))
		draw_circle(disc, 4.8, _light(Color(AMBER, 0.5 + 0.4 * pulse)))
		draw_circle(disc, 11.0 + 3.0 * pulse, _light(Color(AMBER, 0.12)))
	# Neck ring and helmet, a visor band across the front and a glint along it.
	draw_rect(Rect2(neck.x - 5.0, neck.y - 4.0, 12.0, 8.0), under)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-11.0, 4.0), head + Vector2(-10.0, -10.0), head + Vector2(-3.0, -16.0),
		head + Vector2(8.0, -15.0), head + Vector2(14.0, -7.0), head + Vector2(14.0, 3.0), head + Vector2(9.0, 10.0), head + Vector2(-6.0, 10.0)]),
		suit if ghost else _c(Color("#3d444e")))
	draw_line(head + Vector2(-3.0, -15.0), head + Vector2(8.0, -14.0), edge, 1.5)
	draw_colored_polygon(PackedVector2Array([head + Vector2(3.0, -6.0), head + Vector2(14.0, -5.0), head + Vector2(14.0, 2.0), head + Vector2(4.0, 2.0)]), under)
	draw_line(head + Vector2(5.0, -2.0), head + Vector2(14.0, -2.0), trim, 2.0)
	if not ghost:
		var glint := fposmod(time / 5.0, 1.0) * 5.0
		if glint < 1.0:
			draw_circle(head + Vector2(lerpf(5.0, 14.0, glint), -2.0), 1.8, _light(Color("#fff3dc")))
	# Near arm in front: shoulder pad, armoured forearm, the palm that lifts.
	var near_shoulder := neck + Vector2(12.0, 8.0)
	var near_hand := (near_shoulder + Vector2(5.0, 47.0)).lerp(near_shoulder + Vector2(31.0, 20.0), lift)
	_echo_arm(near_shoulder, near_hand, suit, plate, lift)
	draw_colored_polygon(PackedVector2Array([near_shoulder + Vector2(-7.0, -6.0), near_shoulder + Vector2(9.0, -8.0),
		near_shoulder + Vector2(12.0, 3.0), near_shoulder + Vector2(-4.0, 7.0)]), plate)
	draw_line(near_shoulder + Vector2(-7.0, -6.0), near_shoulder + Vector2(9.0, -8.0), edge, 1.5)
	if not ghost and lift > 0.05:
		# Light gathered in the open palm.
		draw_circle(near_hand + Vector2(0.0, -7.0), 3.0 + 4.0 * lift, _light(Color(AMBER, 0.6 * lift)))
		draw_circle(near_hand + Vector2(0.0, -7.0), 9.0 + 7.0 * lift, _light(Color(AMBER, 0.14 * lift)))


## Thigh and shin, a knee guard, a shin plate and a boot.
func _echo_leg(hip: Vector2, foot: Vector2, cloth: Color, armour: Color) -> void:
	var knee := (hip + foot) * 0.5 + Vector2(4.0, 0.0)
	_capsule(hip, knee, 12.0, cloth)
	_capsule(knee, foot + Vector2(0.0, -8.0), 10.0, cloth)
	draw_colored_polygon(PackedVector2Array([knee + Vector2(-3.0, -6.0), knee + Vector2(7.0, -5.0), knee + Vector2(7.0, 4.0), knee + Vector2(-2.0, 6.0)]), armour)
	draw_line(knee + Vector2(4.0, 7.0), foot + Vector2(4.0, -13.0), armour, 4.0, true)
	draw_colored_polygon(PackedVector2Array([foot + Vector2(-6.0, -12.0), foot + Vector2(6.0, -12.0), foot + Vector2(16.0, -4.0),
		foot + Vector2(16.0, 0.0), foot + Vector2(-7.0, 0.0)]), armour)


## Upper arm in the suit, an armoured forearm, a gauntlet.
func _echo_arm(shoulder: Vector2, hand: Vector2, cloth: Color, armour: Color, lift: float = 0.0) -> void:
	var elbow := (shoulder + hand) * 0.5 + Vector2(-3.0 + 9.0 * lift, 6.0 - 6.0 * lift)
	_capsule(shoulder, elbow, 9.5, cloth)
	_capsule(elbow, hand, 10.5, armour)
	draw_circle(hand, 5.5, cloth)


func _capsule(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, color, width, true)
	draw_circle(a, width * 0.5, color, true, -1.0, true)
	draw_circle(b, width * 0.5, color, true, -1.0, true)
