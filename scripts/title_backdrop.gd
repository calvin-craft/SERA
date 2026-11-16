extends Control

const TitlePortrait = preload("res://scripts/title_portrait.gd")
const DESIGN_SIZE := Vector2(1152, 648)
var clock := 0.0

@onready var artwork: Node2D = $Artwork
@onready var portrait: TitlePortrait = $Artwork/Sera
@onready var catwalk: Sprite2D = $Artwork/Catwalk
@onready var pipes: Sprite2D = $Artwork/Pipes
@onready var catwalk_origin: Vector2 = catwalk.position
@onready var pipes_origin: Vector2 = pipes.position
@onready var portrait_origin: Vector2 = portrait.position
@onready var portrait_rest_scale: Vector2 = portrait.scale


func _ready() -> void:
	resized.connect(_fit_artwork)
	_fit_artwork()


func _process(delta: float) -> void:
	clock += delta
	catwalk.position = catwalk_origin + Vector2(12.0 * sin(clock * 0.30), 3.0 * sin(clock * 0.19))
	pipes.position = pipes_origin + Vector2(23.0 * sin(clock * 0.26), 5.0 * sin(clock * 0.21))
	portrait.pose_at(clock)


func _fit_artwork() -> void:
	var zoom := maxf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if zoom <= 0.0:
		return
	artwork.scale = Vector2.ONE * zoom
	artwork.position = (size - DESIGN_SIZE * zoom) * 0.5

	# Keep Sera framed against the right edge as the background crops to fit.
	var visible_area := size / zoom
	var frame_origin := (DESIGN_SIZE - visible_area) * 0.5
	var portrait_zoom := visible_area.y / DESIGN_SIZE.y
	portrait.scale = portrait_rest_scale * portrait_zoom
	portrait.position = frame_origin + Vector2(
		visible_area.x - (DESIGN_SIZE.x - portrait_origin.x) * portrait_zoom,
		portrait_origin.y * portrait_zoom
	)
