extends Control

const Reactor = preload("res://scripts/reactor.gd")
const MenuTheme = preload("res://scripts/menu_theme.gd")
const Texts = preload("res://texts.gd")
const COOL := Color("#7ee8fc")
const HOT := Color("#ff996c")
const INK := Color("#e6f0ee")
const EMPTY := Color("#26343b")
const PLATE := Color(0.03, 0.04, 0.05, 0.86)

var life := 0.0
var last_health := -1
var hit_flash := 0.0
var shown_health := 0.0
@onready var level: Reactor = $"../.."


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	life += delta
	var health: int = level.boss.health
	if last_health < 0:
		shown_health = health
	elif health < last_health:
		hit_flash = 1.0
	last_health = health
	shown_health = move_toward(shown_health, health, delta * 1.6)
	hit_flash = move_toward(hit_flash, 0.0, delta * 1.8)
	queue_redraw()


func _draw() -> void:
	if level.complete:
		return
	var boss := level.boss
	var open := boss.is_open()
	var width := 436.0
	var left := (size.x - width) * 0.5
	var top := 24.0
	var tint := COOL if open else HOT
	var plate := Rect2(left, top, width, 66)
	MenuTheme.slant(self, plate, PLATE, 16.0)
	MenuTheme.slant(self, Rect2(left, top, width, 3), Color(tint, 0.9), 0.0)
	if hit_flash > 0.0:
		MenuTheme.slant(self, plate, Color(Color.WHITE, 0.25 * hit_flash), 16.0)

	var text_font := MenuTheme.text_font(700)
	var label_font := MenuTheme.display_font(600)
	MenuTheme.slant(self, Rect2(left + 22, top + 12, 48, 18), Color(HOT, 0.9), 6.0)
	draw_string(label_font, Vector2(left + 22, top + 26), Texts.HUD_BOSS, HORIZONTAL_ALIGNMENT_CENTER, 48, 12, MenuTheme.INK)
	draw_string(text_font, Vector2(left + 80, top + 28), Texts.BOSS_REACTOR, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	var state: String = Texts.REACTOR_STATUS_OPEN if open else Texts.REACTOR_STATUS_SHUT
	if boss.dormant:
		state = Texts.HUD_BOSS_DORMANT
		tint = MenuTheme.MUTED
	var blink := 0.75 + 0.25 * sin(life * (10.0 if open else 3.0))
	draw_string(text_font, Vector2(left, top + 28), state, HORIZONTAL_ALIGNMENT_RIGHT, width - 30, 14, Color(tint, blink))

	# One long slanted bar split into the three cores; lost cores drain away.
	var bar := Rect2(left + 24, top + 38, width - 54, 12)
	var gap := 6.0
	var cell := (bar.size.x - gap * (boss.CORE_HITS - 1)) / boss.CORE_HITS
	for i in boss.CORE_HITS:
		var r := Rect2(bar.position.x + i * (cell + gap), bar.position.y, cell, bar.size.y)
		MenuTheme.slant(self, r, EMPTY, 6.0)
		var fill := clampf(shown_health - i, 0.0, 1.0)
		if fill > 0.0:
			var color := tint
			if i >= boss.health:
				color = Color.WHITE.lerp(HOT, 1.0 - hit_flash)
			elif open and i == boss.health - 1:
				color = tint.lerp(Color.WHITE, 0.3 + 0.3 * sin(life * 12.0))
			MenuTheme.slant(self, Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), color, 6.0)
	if open:
		var ratio: float = boss.state_left / boss.OPEN_TIME
		draw_rect(Rect2(bar.position.x + 4, bar.end.y + 5, (bar.size.x - 8) * ratio, 3), COOL)
