extends Node

## 기우는 갑판. The cargo ship rolls in the swell. Between calm spells the deck
## leans to one side for a few seconds: the view rolls with it, Sera's feet
## slide downhill (a jump is not pushed), and the barrel racks on the decks
## let a barrel go from their uphill end. The sides follow `pattern`
## ("R" leans so things slide right, "L" so they slide left). A creak and a
## flicker on the racks come just before each lean.

signal leaning(side: float)
signal warned(side: float)

const Sera = preload("res://scripts/sera.gd")
const RAMP := 0.55
const WARNING := 0.8

@export var calm_time := 2.8
@export var lean_time := 2.6
## Push on Sera's feet at full lean, in pixels per second.
@export var slide := 165.0
## How far the view rolls at full lean, in degrees.
@export var max_angle := 3.5
@export var pattern := "RL"
@export var phase := 0.0

var target: Sera
var clock := 0.0
## -1 to 1, eased: positive means the right side is low and things slide right.
var lean := 0.0
var last_leg := -1
var warned_leg := -1


func _ready() -> void:
	restart()


func restart() -> void:
	clock = phase
	lean = _goal()
	last_leg = _leg() if _goal() != 0.0 else -1
	warned_leg = last_leg


func cycle_time() -> float:
	return calm_time + lean_time


func _leg() -> int:
	return floori(clock / cycle_time())


## The side of the lean that this cycle ends with.
func side_of(leg: int) -> float:
	if pattern.is_empty():
		return 1.0
	return 1.0 if pattern[posmod(leg, pattern.length())] == "R" else -1.0


func _goal() -> float:
	return side_of(_leg()) if fposmod(clock, cycle_time()) >= calm_time else 0.0


## True in the moment before a lean starts.
func warning() -> bool:
	var t := fposmod(clock, cycle_time())
	return t >= calm_time - WARNING and t < calm_time


## The side the next (or current) lean goes to.
func coming_side() -> float:
	return side_of(_leg())


func is_leaning() -> bool:
	return absf(lean) > 0.35


## The roll of the view, in radians, for the camera.
func roll() -> float:
	return -lean * deg_to_rad(max_angle)


func _physics_process(delta: float) -> void:
	clock += delta
	var goal := _goal()
	lean = move_toward(lean, goal, delta / RAMP)
	var leg := _leg()
	if warning() and warned_leg != leg:
		warned_leg = leg
		warned.emit(side_of(leg))
	if goal != 0.0 and last_leg != leg:
		last_leg = leg
		leaning.emit(goal)
	if absf(lean) > 0.01 and is_instance_valid(target) and target.integrity > 0 \
			and target.is_on_floor() and target.state != Sera.State.BOOST:
		target.move_and_collide(Vector2(slide * lean * delta, 0.0))
