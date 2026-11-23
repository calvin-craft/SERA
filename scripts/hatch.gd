extends StaticBody2D

## 금간 해치. A cracked plate over a shaft. A shockwave fired downward (S + RMB)
## breaks it, whether Sera stands on it or fires from the air above. Once open
## it stays open. The node sits at the centre of the plate's top surface.

signal broken(origin: Vector2)

const THICKNESS := 22.0
const PLATE := Color("#2f3d44")
const EDGE := Color("#7f9298")
const CRACK := Color("#0d161b")
const WARN := Color("#ffb46e")

@export var half_width := 70.0

var open := false
## 1 → 0 while the pieces fall after it breaks.
var crumble := 0.0
var shape: CollisionShape2D
var clock := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(half_width * 2.0, THICKNESS)
	shape.shape = box
	shape.position = Vector2(0.0, THICKNESS * 0.5)
	add_child(shape)


func break_open(quiet: bool = false) -> void:
	if open:
		return
	open = true
	shape.set_deferred(&"disabled", true)
	crumble = 0.0 if quiet else 1.0
	if not quiet:
		broken.emit(global_position + Vector2(0.0, THICKNESS * 0.5))
	queue_redraw()


func _process(delta: float) -> void:
	clock += delta
	if crumble > 0.0:
		crumble = maxf(0.0, crumble - delta * 1.5)
	if crumble > 0.0 or not open:
		queue_redraw()


func _draw() -> void:
	if open:
		_draw_open()
		return
	draw_rect(Rect2(-half_width, 0.0, half_width * 2.0, THICKNESS), PLATE)
	draw_line(Vector2(-half_width, 0.0), Vector2(half_width, 0.0), EDGE, 2.0)
	draw_rect(Rect2(-half_width, THICKNESS - 4.0, half_width * 2.0, 4.0), CRACK)
	# Warning chevrons at both ends say "this one gives".
	var glow := 0.55 + 0.25 * sin(clock * 4.0)
	for side in [-1.0, 1.0]:
		var x: float = side * (half_width - 14.0)
		draw_polyline(PackedVector2Array([Vector2(x - 6.0, 6.0), Vector2(x, 12.0), Vector2(x + 6.0, 6.0)]), Color(WARN, glow), 2.0, true)
	# The crack itself.
	var crack := PackedVector2Array()
	var steps := 7
	for index in steps + 1:
		var x := lerpf(-half_width * 0.7, half_width * 0.7, float(index) / steps)
		crack.append(Vector2(x, 4.0 + (index % 2) * 12.0))
	draw_polyline(crack, CRACK, 3.0, true)
	draw_line(Vector2(-half_width * 0.2, 10.0), Vector2(-half_width * 0.32, 20.0), CRACK, 2.0, true)
	draw_line(Vector2(half_width * 0.25, 6.0), Vector2(half_width * 0.38, -1.0), CRACK, 2.0, true)


func _draw_open() -> void:
	# Torn lips on both sides of the hole.
	for side in [-1.0, 1.0]:
		var edge: float = side * half_width
		draw_colored_polygon(PackedVector2Array([Vector2(edge, 0.0), Vector2(edge - side * 18.0, 0.0),
			Vector2(edge - side * 10.0, 9.0), Vector2(edge - side * 20.0, 16.0), Vector2(edge, THICKNESS)]), PLATE)
		draw_line(Vector2(edge, 0.0), Vector2(edge - side * 18.0, 0.0), EDGE, 2.0)
	if crumble <= 0.0:
		return
	# Pieces drop away and fade.
	var fall := (1.0 - crumble)
	for index in 6:
		var x := lerpf(-half_width * 0.75, half_width * 0.75, index / 5.0)
		var y := 8.0 + fall * fall * (260.0 + index * 30.0)
		var spin := fall * (3.0 + index)
		draw_set_transform(Vector2(x, y), spin, Vector2.ONE)
		draw_rect(Rect2(-12.0, -6.0, 24.0, 12.0), Color(PLATE, crumble))
		draw_set_transform(Vector2.ZERO)
