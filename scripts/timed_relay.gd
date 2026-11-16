extends "res://scripts/kinetic_relay.gd"

## A relay that only holds its charge for a few seconds. Whatever it powers
## switches back off when the charge runs out, so it has to be hit again.

signal expired

@export var hold_time := 2.6

var left := 0.0


func energize(quiet: bool = false) -> void:
	# A held charge is never restored from a save: it would have run out anyway.
	if powered or quiet:
		return
	super.energize(false)
	left = hold_time
	set_process(true)


func expire() -> void:
	if powered:
		powered = false
		left = 0.0
		expired.emit()
		queue_redraw()


func _process(delta: float) -> void:
	age += delta
	pulse = maxf(0.0, pulse - delta * 1.9)
	if powered:
		left -= delta
		if left <= 0.0:
			expire()
	queue_redraw()


func _draw() -> void:
	super._draw()
	# Outer dial: full when just hit, draining clockwise.
	draw_arc(Vector2.ZERO, 47.0, 0.0, TAU, 44, Color("#16272e"), 5.0, true)
	if powered:
		var ratio := clampf(left / hold_time, 0.0, 1.0)
		var tint := LIVE if ratio > 0.3 or int(age * 10.0) % 2 == 0 else WAITING
		draw_arc(Vector2.ZERO, 47.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 44, tint, 3.0, true)
	else:
		for tick in 12:
			var dir := Vector2.from_angle(TAU * tick / 12.0)
			draw_line(dir * 44.0, dir * 50.0, Color(WAITING, 0.7), 1.5, true)
