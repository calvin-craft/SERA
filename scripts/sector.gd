extends "res://scripts/stage.gd"

## A scrolling stage whose layout lives in its scene. The stage reads decks,
## checkpoints and machines from $World; a short subclass says how they are
## connected in _wire() (which foe opens which gate, which relay powers what)
## and adds the stage's own lines for Sera.
##
## Scene contract, all under $World:
##   Walkways/*        CollisionShape2D rectangles: the solid decks
##   Checkpoints/*     Marker2D, left to right: checkpoints 1, 2, …
##   AimPads/*         Marker2D: floor marks for diagonal shots (optional)
##   Exit              Marker2D: where the exit portal stands
##   anything else     wardens, relays, belts, hazards, shuttles, rams, drones

const Conveyor = preload("res://scripts/conveyor.gd")
const Hazard = preload("res://scripts/hazard_gate.gd")
const Shuttle = preload("res://scripts/shuttle.gd")
const Shutter = preload("res://scripts/shutter.gd")
const TimedRelay = preload("res://scripts/timed_relay.gd")
const Ram = preload("res://scripts/ram.gd")
const Drone = preload("res://scripts/drone.gd")
const Valve = preload("res://scripts/pulse_valve.gd")
const AimGuide = preload("res://scripts/sector_guide.gd")
const POWER := Color("#7eead8")
const LINE_TIME := 4.6

## Left and right limits of the camera centre.
@export var camera_x := Vector2(576.0, 4000.0)
## Top and bottom limits of the camera centre.
@export var camera_y := Vector2(342.0, 342.0)

var spawns: Array[Vector2] = []
var decks: Array[Rect2] = []
var belts: Array[Conveyor] = []
var hazards: Array[Hazard] = []
var shuttles: Array[Shuttle] = []
var shutters: Array[Shutter] = []
var valves: Array[Valve] = []
var rams: Array[Ram] = []
var drones: Array[Drone] = []
var gates: Array[Bulkhead] = []
var aim_pads: Array[Vector2] = []
var exit_point := Vector2.INF
var exit_gate: Bulkhead
## [what opens or shuts down, the foes that must fall first, already announced]
var locks: Array = []
## [relay, the thing it powers]
var power_links: Array = []
## [world x where Sera says it, id, text]
var lines: Array = []
var line_age := 0.0
var ground_y := 0.0
var last_belt: Conveyor
var belt_left := 0.0
var steam_tone: AudioStreamPlayer

@onready var deck_art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


func _ready() -> void:
	var world := $World
	for node in world.get_children():
		if node is Guard:
			guards.append(node)
		elif node is Relay:
			relays.append(node)
		elif node is Conveyor:
			belts.append(node)
		elif node is Hazard:
			hazards.append(node)
		elif node is Shuttle:
			shuttles.append(node)
		elif node is Shutter:
			shutters.append(node)
		elif node is Valve:
			valves.append(node)
		elif node is Ram:
			rams.append(node)
		elif node is Drone:
			drones.append(node)
		elif node is Bulkhead:
			gates.append(node)
	for shape: CollisionShape2D in world.get_node("Walkways").get_children():
		var size: Vector2 = shape.shape.size
		decks.append(Rect2(shape.position - size * 0.5, size))
	spawns = [sera.position]
	for marker: Node2D in world.get_node("Checkpoints").get_children():
		spawns.append(marker.position)
	if world.has_node("AimPads"):
		for marker: Node2D in world.get_node("AimPads").get_children():
			aim_pads.append(marker.position)
	if world.has_node("Exit"):
		exit_point = world.get_node("Exit").position
	ground_y = sera.position.y
	_use_own_backdrop()
	_wire()
	super._ready()

	for valve in valves:
		valve.target = sera
		_bind_weapon(valve)
	for drone in drones:
		drone.target = sera
		_bind_weapon(drone)
		drone.crashed.connect(_on_warden_crash)
	for ram in rams:
		ram.target = sera
		ram.attack_prepared.connect(_on_ram_warning)
		ram.precision_ready.connect(_play.bind(Audio.BRACE_CUE, -4.5))
		ram.caught.connect(_on_ram_caught)
		ram.braked.connect(_on_ram_braked)
	for hazard in hazards:
		hazard.target = sera
		hazard.warned.connect(_on_hazard_warning)
		hazard.burst.connect(_on_hazard_burst)
	if hazards.any(func(hazard: Hazard): return hazard.kind == "steam"):
		steam_tone = Audio.start_room(self, Audio.STEAM_BED, -56.0)
		steam_tone.name = "SteamTone"
	for shutter in shutters:
		shutter.blocker = sera
	for relay in relays:
		relay.activated.connect(_on_relay_activated.bind(relay))
		if relay is TimedRelay:
			relay.expired.connect(deck_art.queue_redraw)
	sera.forward_brace = true
	camera.position = _camera_goal(sera.position)
	var guide := AimGuide.new()
	guide.level = self
	guide.z_index = 2
	world.add_child(guide)


func _process(delta: float) -> void:
	super._process(delta)
	if steam_tone == null or player_paused:
		return
	var mix := 0.0
	if not complete:
		for hazard in hazards:
			if hazard.kind == "steam" and hazard.active():
				var gap := (hazard.global_position - sera.global_position) * Vector2(1.0, 1.6)
				mix = maxf(mix, 1.0 - gap.length() / 460.0)
	var gain := move_toward(db_to_linear(steam_tone.volume_db), 0.54 * pow(mix, 1.6), delta * 2.7)
	steam_tone.volume_db = linear_to_db(maxf(0.001, gain))


func _set_player_pause(value: bool) -> void:
	super._set_player_pause(value)
	if steam_tone != null:
		steam_tone.stream_paused = value


## Subclasses connect the stage's machines here, before anything is restored.
func _wire() -> void:
	pass


## `target` (a bulkhead, or a hazard to shut down) opens once every foe is down.
func open_when_down(target: Node, foes: Array) -> void:
	locks.append([target, foes, false])


## `target` has power exactly while `relay` is energized.
func power(relay: Relay, target: Node) -> void:
	power_links.append([relay, target])


## Sera says `text` once, the first time she passes world x `at`.
func say(at: float, id: StringName, text: String) -> void:
	lines.append([at, id, text])


func _use_own_backdrop() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		backdrop.modulate = Color(0.9, 0.93, 0.95)


func _is_down(foe: Node) -> bool:
	return foe.knocked_out if foe is Guard else foe.down


func _update_progress() -> void:
	if sera.is_on_floor() or sera.position.y > ground_y + 150.0:
		ground_y = sera.position.y
	if sera.is_on_floor():
		for index in range(spawns.size() - 1, checkpoint, -1):
			var point := spawns[index]
			if sera.position.x >= point.x - 24.0 and absf(sera.position.y - point.y) < 48.0:
				_reach_checkpoint(index, point)
				deck_art.queue_redraw()
				break
	_apply_links(false)
	_notice_passed_machines()
	# One story line at a time. It counts as said once it has actually been on
	# screen for a few seconds, so a more urgent hint never swallows it.
	for line: Array in lines:
		if knows(line[1]):
			continue
		var shown := hud_hints()
		if not shown.is_empty() and shown[0]["id"] == line[1]:
			line_age += get_physics_process_delta_time()
			if line_age >= LINE_TIME:
				line_age = 0.0
				learn(line[1])
		break


## The shared hints stop once the player has got past the machine in question.
func _notice_passed_machines() -> void:
	var at := sera.position
	var belt := belt_under_sera()
	if belt != null:
		last_belt = belt
		belt_left = 0.3
	else:
		belt_left = maxf(0.0, belt_left - get_physics_process_delta_time())
		if last_belt != null and sera.is_on_floor():
			if last_belt.speed < 0.0 and at.x > last_belt.position.x + last_belt.length - 12.0:
				learn(&"belt_back")
			last_belt = null
		elif belt_left > 0.0 and sera.air_carry and absf(sera.velocity.x) > Sera.RUN_SPEED + 40.0:
			learn(&"belt")
	for hazard in hazards:
		if absf(hazard.position.y - at.y) < 110.0 and at.x > hazard.position.x + 50.0 and at.x < hazard.position.x + 170.0:
			learn(&"press" if hazard.kind == "press" else (&"steam_dash" if hazard.always_on else &"steam"))


func _apply_links(quiet: bool) -> void:
	for lock: Array in locks:
		if lock[2]:
			continue
		var clear := true
		for foe: Node in lock[1]:
			clear = clear and _is_down(foe)
		if not clear:
			continue
		lock[2] = true
		var target: Node = lock[0]
		if target is Bulkhead:
			target.unlock(quiet)
			if not quiet:
				_show_feedback(Texts.NOTE_EXIT_OPEN if target == exit_gate else Texts.SECTOR_NOTE_PASSAGE, ICE)
		elif target is Hazard:
			target.shut_down()
			if not quiet:
				_show_feedback(Texts.SECTOR_NOTE_STEAM_CUT, POWER)
	for link: Array in power_links:
		var powered: bool = link[0].powered
		if link[1] is Guard:
			# A relay feeding a warden's shield: cutting it is permanent.
			if powered and link[1].shielded:
				link[1].shielded = false
				link[1].queue_redraw()
		else:
			link[1].set_powered(powered)


func _exit_spot() -> Vector2:
	return exit_point


func _exit_ready() -> bool:
	return exit_gate == null or exit_gate.unlocked


func _saved_spawn(index: int) -> Vector2:
	return spawns[clampi(index, 0, spawns.size() - 1)]


## Loading a checkpoint: everything behind it has already been dealt with.
func _restore_room_progress() -> void:
	if checkpoint > 0:
		var edge := spawns[checkpoint].x - 40.0
		for guard in guards:
			if guard.home.x < edge and not guard.knocked_out:
				guard.restore_defeated()
		for ram in rams:
			if ram.home.x < edge:
				ram.restore_defeated()
		for drone in drones:
			if drone.home_x < edge:
				drone.restore_defeated()
		for relay in relays:
			if relay.restore_behind_checkpoint and relay.position.x < edge:
				relay.energize(true)
		for gate in gates:
			if gate.position.x < edge:
				gate.unlock(true)
	_apply_links(true)
	ground_y = spawns[checkpoint].y
	deck_art.queue_redraw()


func _reset_room() -> void:
	for valve in valves:
		valve.reset_valve()
	for ram in rams:
		if not ram.down:
			ram.reset_foe()
	for drone in drones:
		if not drone.down:
			drone.reset_foe()
	for shuttle in shuttles:
		shuttle.park()
	for hazard in hazards:
		hazard.restart()
	for relay in relays:
		if relay is TimedRelay:
			relay.expire()
	ground_y = checkpoint_position.y


func _resolve_stage_wave(next_distance: float) -> void:
	var push := signf(wave_direction.x)
	for ram in rams:
		if ram.down or ram in wave_hits or not _wave_reaches(ram.hit_point(), 70.0, next_distance):
			continue
		wave_hits.append(ram)
		if ram.take_wave(push):
			learn(&"ram_break")
			effects.impact(ram.hit_point(), true)
			_play(Audio.CORE_BREAK, -5.0, 0.87)
			_show_feedback(Texts.SECTOR_NOTE_RAM_BROKEN, ICE)
			_hitstop(0.086, 10.5, 0.13, ICE)
		else:
			effects.impact(ram.hit_point(), false)
			_play(Audio.ARMOR, -4.0)
			_show_feedback(Texts.SECTOR_NOTE_RAM_ARMOR, HEAT)
	for drone in drones:
		if drone.down or drone in wave_hits or not _wave_reaches(drone.hit_point(), drone.HIT_RADIUS, next_distance):
			continue
		wave_hits.append(drone)
		drone.take_wave(push)
		learn(&"drone_break")
		effects.impact(drone.hit_point(), true)
		_play(Audio.CORE_BREAK, -7.0, 1.14)
		_show_feedback(Texts.SECTOR_NOTE_DRONE_DOWN, ICE)
		_hitstop(0.07, 8.0, 0.1, ICE)


func _on_guard_hit(guard: Guard) -> void:
	if not guard.knocked_out:
		_show_feedback(Texts.NOTE_ARMOR_BROKEN, HEAT)


func _on_ram_warning(_sweep: bool) -> void:
	_play(Audio.CHARGE_CUE, -6.0)


func _on_ram_caught(origin: Vector2, charge: int, precise: bool) -> void:
	learn(&"ram_catch")
	caught_shots += 1
	if precise:
		perfect_shots += 1
	var message: String = Texts.SECTOR_NOTE_RAM_CAUGHT_PRECISE if precise else Texts.SECTOR_NOTE_RAM_CAUGHT
	if charge > 0:
		message += "  +%d" % charge
	_show_feedback(message, ICE)
	effects.catch_energy(origin)
	_play(Audio.PRECISE_CATCH if precise else Audio.HEAVY_CATCH, -1.5, 0.93)
	_hitstop(0.11 if precise else 0.08, 9.0, 0.13, ICE)


func _on_ram_braked(origin: Vector2) -> void:
	if absf(origin.x - sera.position.x) < 700.0:
		effects.impact(origin, false)
		_play(Audio.IMPACT, -12.0, 0.74)


func _on_hazard_warning(origin: Vector2, press: bool) -> void:
	var gap := origin - sera.global_position
	if absf(gap.x) < 365.0 and absf(gap.y) < 150.0:
		_play(Audio.PRESS_CUE if press else Audio.STEAM_CUE, -8.0)


func _on_hazard_burst(origin: Vector2, press: bool) -> void:
	if absf(origin.x - sera.position.x) > 520.0 or absf(origin.y - sera.position.y) > 200.0:
		return
	if press:
		effects.impact(origin, true)
		_play(Audio.IMPACT, -7.0, 0.80)
		shake = maxf(shake, 4.5)
	else:
		_play(Audio.STEAM, -9.0)


func _on_relay_activated(relay: Relay) -> void:
	learn(&"timed" if relay is TimedRelay else &"relay")
	deck_art.queue_redraw()
	effects.catch_shot(relay.global_position, true)
	_show_feedback(Texts.SECTOR_NOTE_TIMED_RELAY if relay is TimedRelay else Texts.SECTOR_NOTE_RELAY, POWER)
	_play(Audio.RELAY, -3.0)
	_hitstop(0.063, 4.0, 0.07, ICE)


func _camera_goal(point: Vector2) -> Vector2:
	var lead := 127.0 + clampf(sera.velocity.x * 0.12, -96.0, 115.0)
	return Vector2(clampf(point.x + lead, camera_x.x, camera_x.y), clampf(ground_y - 178.0, camera_y.x, camera_y.y))


func _update_backdrop() -> void:
	var span := maxf(1.0, camera_x.y - camera_x.x)
	var rise := maxf(1.0, camera_y.y - camera_y.x)
	backdrop.position = Vector2(-40.0 - 150.0 * clampf((camera.position.x - camera_x.x) / span, 0.0, 1.0),
		-30.0 - (60.0 * clampf((camera.position.y - camera_y.x) / rise, 0.0, 1.0) if camera_y.y > camera_y.x else 0.0))


func hud_section() -> String:
	return stage_label(checkpoint)


func hud_marker() -> Array:
	if exit_point.is_finite() and _exit_ready():
		return [exit_point + Vector2(0.0, -214.0), Texts.MARK_EXIT, ICE]
	return []


## What a diagonal shot can usefully hit: [world point, hit radius] pairs.
func aim_candidates() -> Array:
	var candidates := []
	for relay in relays:
		if not relay.powered:
			candidates.append([relay.global_position, relay.HIT_RADIUS])
	for drone in drones:
		if not drone.down:
			candidates.append([drone.global_position, drone.HIT_RADIUS])
	return candidates


## The belt Sera is standing on, or null.
func belt_under_sera() -> Conveyor:
	if sera.is_on_floor():
		for belt in belts:
			if absf(belt.position.y - sera.position.y) < 6.0 and sera.position.x > belt.position.x \
					and sera.position.x < belt.position.x + belt.length:
				return belt
	return null


## What Sera says about the machines every sector shares. Each line appears
## until the player has done the thing once this session.
func stage_hints() -> Array:
	var hints := []
	var at := sera.global_position
	for ram in rams:
		if ram.down or absf(ram.global_position.x - at.x) > 600.0 or absf(ram.global_position.y - at.y) > 110.0:
			continue
		if ram.is_threat() and not knows(&"ram_catch"):
			hints.append(hint(&"ram_catch", ram.hit_point() + Vector2(0.0, -60.0),
				spoken(Texts.SECTOR_HINT_RAM_CATCH, [["LMB"]]), HEAT))
		elif ram.is_stunned() and not knows(&"ram_break") and sera.energy >= Sera.RELEASE_COST:
			hints.append(hint(&"ram_break", ram.hit_point() + Vector2(0.0, -60.0),
				spoken(Texts.SECTOR_HINT_RAM_BREAK, [["RMB"]])))
	for drone in drones:
		if drone.down or knows(&"drone_break") or absf(drone.global_position.x - at.x) > 560.0 or absf(drone.floor_y - at.y) > 130.0:
			continue
		if sera.energy >= Sera.RELEASE_COST:
			if drone.is_low():
				hints.append(hint(&"drone_break", drone.global_position, spoken(Texts.SECTOR_HINT_DRONE_LOW, [["RMB"]])))
			else:
				hints.append(hint(&"drone_break", drone.global_position,
					spoken(Texts.SECTOR_HINT_DRONE_HIGH, [["W", "+", "RMB"]]), POWER))
		elif not knows(&"drone_shot"):
			hints.append(hint(&"drone_shot", drone.global_position, spoken(Texts.SECTOR_HINT_DRONE_SHOT, [["LMB"]])))
		break
	for hazard in hazards:
		if hazard.is_shut() or absf(hazard.global_position.y - at.y) > 110.0:
			continue
		var gap := hazard.global_position.x - at.x
		if gap < 40.0 or gap > 330.0 or sera.facing < 0.0:
			continue
		if hazard.kind == "press":
			if not knows(&"press"):
				hints.append(hint(&"press", hazard.global_position + Vector2(0.0, -150.0), spoken(Texts.SECTOR_HINT_PRESS), HEAT))
		elif hazard.always_on:
			if not knows(&"steam_dash"):
				if sera.energy >= Sera.BOOST_COST:
					hints.append(hint(&"steam_dash", hazard.global_position + Vector2(0.0, -150.0),
						spoken(Texts.SECTOR_HINT_STEAM_DASH, [["Shift"]]), HEAT))
				else:
					hints.append(hint(&"steam_wait", hazard.global_position + Vector2(0.0, -150.0), spoken(Texts.SECTOR_HINT_STEAM_WAIT), HEAT))
		elif not knows(&"steam"):
			hints.append(hint(&"steam", hazard.global_position + Vector2(0.0, -150.0), spoken(Texts.SECTOR_HINT_STEAM), HEAT))
		break
	var belt := belt_under_sera()
	if belt != null:
		if belt.speed * sera.facing > 0.0 and not knows(&"belt"):
			hints.append(hint(&"belt", Vector2.INF, spoken(Texts.SECTOR_HINT_BELT, [["Space"]])))
		elif belt.speed * sera.facing < 0.0 and not knows(&"belt_back"):
			hints.append(hint(&"belt_back", Vector2.INF, spoken(Texts.SECTOR_HINT_BELT_BACK, [["Space"]]), HEAT))
	for relay in relays:
		if relay is TimedRelay and not relay.powered and not knows(&"timed") and sera.energy >= Sera.RELEASE_COST \
				and absf(relay.global_position.x - at.x) < 330.0 and at.y - relay.global_position.y < 420.0 and at.y > relay.global_position.y:
			hints.append(hint(&"timed", relay.global_position,
				spoken(Texts.SECTOR_HINT_TIMED_RELAY, [["W", "+", "RMB"]]), POWER))
			break
	for line: Array in lines:
		if knows(line[1]):
			continue
		if sera.position.x >= line[0]:
			hints.append(hint(line[1], Vector2.INF, [[[], line[2]]]))
		break
	return hints


func _on_shot_absorbed(origin: Vector2, charge: int, precise: bool) -> void:
	super._on_shot_absorbed(origin, charge, precise)
	learn(&"drone_shot")
