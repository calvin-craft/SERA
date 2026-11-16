extends Node2D

const ICE := Color("#61dcff")
const PALE := Color("#b9f5ff")
const HEAT := Color("#ffa965")
const WAVE_TIME := 0.38


class Pulse:
	var kind: StringName
	var origin: Vector2
	var angle: float
	var life: float
	var age := 0.0
	var speed := 0.0
	var distance := 0.0

	func _init(p_kind: StringName, p_origin: Vector2, p_angle: float, p_life: float) -> void:
		kind = p_kind
		origin = p_origin
		angle = p_angle
		life = p_life


class Spark:
	var point: Vector2
	var velocity: Vector2
	var shade: Color
	var life: float
	var age := 0.0

	func _init(p_point: Vector2, p_velocity: Vector2, p_shade: Color, p_life: float) -> void:
		point = p_point
		velocity = p_velocity
		shade = p_shade
		life = p_life


class Echo:
	var origin: Vector2
	var texture: Texture2D
	var facing: float
	var life := 0.21

	func _init(p_origin: Vector2, p_texture: Texture2D, p_facing: float) -> void:
		origin = p_origin
		texture = p_texture
		facing = p_facing


var pulses: Array[Pulse] = []
var sparks: Array[Spark] = []
var echoes: Array[Echo] = []
var rng := RandomNumberGenerator.new()
var _had_effects := false


func catch_energy(origin: Vector2) -> void:
	pulses.append(Pulse.new(&"catch", origin, 0.0, 0.58))
	_sparks(origin, -PI / 2.0, PI, 34, ICE, 175.0)
	_sparks(origin, PI / 2.0, 1.25, 19, HEAT, 136.0)
	queue_redraw()


func catch_shot(origin: Vector2, precise: bool) -> void:
	pulses.append(Pulse.new(&"shot", origin, 0.0, 0.48 if precise else 0.34))
	_sparks(origin, -PI / 2.0, PI, 36 if precise else 21, ICE, 258.0 if precise else 160.0)
	queue_redraw()


func clear() -> void:
	pulses.clear()
	sparks.clear()
	echoes.clear()
	queue_redraw()


func boost(origin: Vector2, facing: float, upward: bool) -> void:
	var angle := atan2(-0.7 if upward else 0.0, facing)
	pulses.append(Pulse.new(&"boost", origin, angle, 0.4))
	_sparks(origin, angle + PI, 0.43, 27, ICE, 490.0)
	queue_redraw()


func release(origin: Vector2, direction: Vector2, speed: float, distance: float) -> void:
	var wave := Pulse.new(&"release", origin, direction.angle(), WAVE_TIME)
	wave.speed = speed
	wave.distance = distance
	pulses.append(wave)
	_sparks(origin, wave.angle, 0.61, 32, ICE, 542.0)
	queue_redraw()


func impact(origin: Vector2, strong: bool, metal: bool = true) -> void:
	var shade := HEAT if metal else PALE
	pulses.append(Pulse.new(&"impact", origin, 0.0, 0.46 if strong else 0.25))
	_sparks(origin, -PI / 2.0, 1.45, 28 if strong else 10, shade, 280.0 if strong else 96.0)
	queue_redraw()


func afterimage(origin: Vector2, texture: Texture2D, facing: float) -> void:
	echoes.append(Echo.new(origin, texture, facing))


func _sparks(origin: Vector2, direction: float, spread: float, count: int, shade: Color, speed: float) -> void:
	for index in count:
		var angle := direction + rng.randf_range(-spread, spread)
		var strength := speed * rng.randf_range(0.22, 1.0)
		sparks.append(Spark.new(origin + Vector2(rng.randf_range(-9, 9), rng.randf_range(-5, 5)),
			Vector2.from_angle(angle) * strength, shade.lerp(PALE, rng.randf() * 0.48), rng.randf_range(0.14, 0.57)))


func _process(delta: float) -> void:
	for pulse in pulses:
		pulse.age += delta
	for spark in sparks:
		spark.age += delta
		spark.point += spark.velocity * delta
		spark.velocity = spark.velocity.move_toward(Vector2(0, 130), delta * 520.0)
	for echo in echoes:
		echo.life -= delta
	pulses = pulses.filter(func(pulse: Pulse) -> bool: return pulse.age < pulse.life)
	sparks = sparks.filter(func(spark: Spark) -> bool: return spark.age < spark.life)
	echoes = echoes.filter(func(echo: Echo) -> bool: return echo.life > 0.0)
	if not pulses.is_empty() or not sparks.is_empty() or not echoes.is_empty():
		queue_redraw()
	elif _had_effects:
		queue_redraw()
	_had_effects = not pulses.is_empty() or not sparks.is_empty() or not echoes.is_empty()


func _draw() -> void:
	for echo in echoes:
		draw_set_transform(echo.origin, 0.0, Vector2(echo.facing, 1.0))
		draw_texture_rect(echo.texture, Rect2(-89.6, -162.4, 179.2, 179.2), false,
			Color(0.32, 0.9, 1.0, (echo.life / 0.21) * 0.36))
	draw_set_transform(Vector2.ZERO)
	for pulse in pulses:
		var progress := pulse.age / pulse.life
		var strength := 1.0 - progress
		match pulse.kind:
			&"catch":
				_draw_capture(pulse.origin, progress, strength)
			&"shot":
				draw_set_transform(pulse.origin, 0.0, Vector2(0.62, 1.0))
				_glow_arc(Vector2.ZERO, lerpf(11.0, 76.0, sqrt(progress)), 0.0, TAU, ICE, strength)
				_glow_arc(Vector2.ZERO, lerpf(62.0, 12.0, progress), -0.35, 4.81, PALE, strength * 0.82)
				draw_set_transform(Vector2.ZERO)
			&"boost":
				_draw_boost(pulse, progress, strength)
			&"release":
				_draw_wave(pulse, progress, strength)
			&"impact":
				draw_set_transform(pulse.origin, 0.0, Vector2(1.0, 0.24))
				_glow_arc(Vector2.ZERO, 6.0 + 120.0 * progress, PI, TAU, PALE, strength * 0.51)
				draw_set_transform(Vector2.ZERO)
	for spark in sparks:
		var strength := 1.0 - spark.age / spark.life
		var tail := spark.point - spark.velocity * (0.038 * strength + 0.007)
		draw_line(spark.point, tail, Color(spark.shade, strength * 0.24), 5.0, true)
		draw_line(spark.point, tail, Color(spark.shade, strength * 0.91), 1.35, true)


func _draw_capture(origin: Vector2, progress: float, strength: float) -> void:
	draw_set_transform(origin, 0.0, Vector2(1.38, 0.58))
	_glow_arc(Vector2.ZERO, lerpf(104.0, 23.0, progress), 0.15 + progress * 3.0, 4.8 + progress * 3.0, ICE, strength)
	_glow_arc(Vector2.ZERO, 24.0 + 121.0 * progress, PI * 1.13, TAU * 1.45, PALE, strength * 0.66)
	draw_set_transform(Vector2.ZERO)
	draw_circle(origin, 16.0 + 37.0 * strength, Color(ICE, strength * 0.10))
	draw_circle(origin, 3.0 + 8.0 * strength, Color(PALE, strength * 0.52))
	for index in 5:
		var angle := TAU * index / 5.0 + progress * 2.0
		var end := origin + Vector2.from_angle(angle) * (35.0 + 87.0 * strength) * Vector2(1.0, 0.52)
		draw_line(origin, end, Color(ICE, strength * 0.39), 1.4, true)


func _draw_boost(pulse: Pulse, progress: float, strength: float) -> void:
	var travel := Vector2.from_angle(pulse.angle)
	var side := travel.orthogonal()
	for index in 5:
		var offset := side * (index - 2) * (6.0 + progress * 15.0)
		var tip := pulse.origin + travel * (24.0 + progress * 60.0) + offset
		var tail := tip - travel * (86.0 + 150.0 * progress - index * 9.0)
		draw_line(tip, tail, Color(ICE, strength * 0.15), 11.0 - index, true)
		draw_line(tip, tail, Color(PALE, strength * 0.75), 2.0, true)


func _draw_wave(pulse: Pulse, progress: float, strength: float) -> void:
	var travel := minf(pulse.distance, pulse.speed * pulse.age)
	var direction := Vector2.from_angle(pulse.angle)
	var wavefront := pulse.origin + direction * travel
	var center := wavefront - direction * 32.0
	var radius := lerpf(39.0, 101.0, sqrt(progress))
	draw_set_transform(center, pulse.angle, Vector2(0.54, 1.0))
	_glow_arc(Vector2.ZERO, radius, -1.23, 1.23, ICE, strength)
	_glow_arc(Vector2(-35, 0), radius * 0.81, -1.4, 1.4, PALE, strength * 0.77)
	_glow_arc(Vector2(-75, 0), radius * 0.58, -1.3, 1.3, ICE, strength * 0.5)
	draw_set_transform(Vector2.ZERO)
	draw_line(pulse.origin, wavefront, Color(ICE, strength * 0.16), 23.0 * strength + 2.0, true)
	draw_line(pulse.origin, wavefront, Color(PALE, strength * 0.68), 2.0, true)
	draw_circle(pulse.origin, 24.0 * strength, Color(PALE, strength * 0.14))


func _glow_arc(center: Vector2, radius: float, start: float, finish: float, tint: Color, intensity: float) -> void:
	draw_arc(center, radius, start, finish, 40, Color(tint, intensity * 0.13), 18.0, true)
	draw_arc(center, radius, start, finish, 40, Color(tint, intensity * 0.37), 7.0, true)
	draw_arc(center, radius, start, finish, 40, Color(PALE, intensity * 0.89), 2.0, true)
