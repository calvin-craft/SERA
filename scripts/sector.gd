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
const Train = preload("res://scripts/freight_train.gd")
const Gust = preload("res://scripts/gust.gd")
const Hatch = preload("res://scripts/hatch.gd")
const Turret = preload("res://scripts/turret.gd")
const Bomber = preload("res://scripts/bomber.gd")
const Launcher = preload("res://scripts/launcher.gd")
const Homing = preload("res://scripts/homing.gd")
const Absorber = preload("res://scripts/absorber.gd")
const ShipSway = preload("res://scripts/ship_sway.gd")
const BarrelRack = preload("res://scripts/barrel_rack.gd")
const ReflectTarget = preload("res://scripts/reflect_target.gd")
const LowGravity = preload("res://scripts/low_gravity.gd")
const POWER := Color("#7eead8")
const GOLD := Color("#ffe09a")
const LINE_TIME := 4.6
## A turret this high fires over a standing Sera: its bolts are caught in the air.
const HIGH_MUZZLE := 120.0

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
var trains: Array[Train] = []
var gusts: Array[Gust] = []
var hatches: Array[Hatch] = []
var turrets: Array[Turret] = []
var bombers: Array[Bomber] = []
var launchers: Array[Launcher] = []
var absorbers: Array[Absorber] = []
var racks: Array[BarrelRack] = []
var targets: Array[ReflectTarget] = []
var fields: Array[LowGravity] = []
## The rolling ship under a chapter three deck stage, or null.
var sway: ShipSway
var tilt_felt := false
var field_felt := false
var aim_pads: Array[Vector2] = []
## Floor spots where a downward release is the way on (optional DownSpots markers).
var down_spots: Array[Vector2] = []
var gust_felt := false
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
		elif node is Train:
			trains.append(node)
		elif node is Gust:
			gusts.append(node)
		elif node is Hatch:
			hatches.append(node)
		elif node is Turret:
			turrets.append(node)
		elif node is Bomber:
			bombers.append(node)
		elif node is Launcher:
			launchers.append(node)
		elif node is Absorber:
			absorbers.append(node)
		elif node is BarrelRack:
			racks.append(node)
		elif node is ReflectTarget:
			targets.append(node)
		elif node is LowGravity:
			fields.append(node)
		elif node is ShipSway:
			sway = node
	for shape: CollisionShape2D in world.get_node("Walkways").get_children():
		var size: Vector2 = shape.shape.size
		decks.append(Rect2(shape.position - size * 0.5, size))
	spawns = [sera.position]
	for marker: Node2D in world.get_node("Checkpoints").get_children():
		spawns.append(marker.position)
	if world.has_node("AimPads"):
		for marker: Node2D in world.get_node("AimPads").get_children():
			aim_pads.append(marker.position)
	if world.has_node("DownSpots"):
		for marker: Node2D in world.get_node("DownSpots").get_children():
			down_spots.append(marker.position)
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
	for turret in turrets:
		turret.target = sera
		_bind_weapon(turret)
		turret.crashed.connect(_on_warden_crash)
	for bomber in bombers:
		bomber.target = sera
		bomber.attack_prepared.connect(_on_bomber_warning)
		bomber.crashed.connect(_on_warden_crash)
		bomber.canister_caught.connect(_on_canister_caught)
		bomber.canister_burst.connect(_on_canister_burst)
	for gust in gusts:
		gust.target = sera
	for hatch in hatches:
		hatch.broken.connect(_on_hatch_broken)
	for launcher in launchers:
		launcher.target = sera
		launcher.attack_prepared.connect(_on_launcher_warning)
		launcher.missile_launched.connect(_on_missile_launched)
		launcher.crashed.connect(_on_warden_crash)
	for absorber in absorbers:
		absorber.target = sera
		_bind_weapon(absorber)
		absorber.echo_fired.connect(_on_echo_fired)
		absorber.drank.connect(_on_absorber_drank)
		absorber.crashed.connect(_on_warden_crash)
	for rack in racks:
		rack.target = sera
		rack.sway = sway
		rack.caught.connect(_on_barrel_caught)
		rack.smashed.connect(_on_barrel_smashed)
	for target in targets:
		target.lit_up.connect(_on_target_lit)
	for field in fields:
		field.target = sera
	if sway != null:
		sway.target = sera
		sway.leaning.connect(_on_ship_leaning)
		sway.warned.connect(_on_ship_warned)
		camera.ignore_rotation = false
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
	if sway != null:
		camera.rotation = sway.roll()
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
		# A painting replaces the code-drawn skyline.
		if has_node("FarBackground/Skyline"):
			get_node("FarBackground/Skyline").hide()


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
	# Riding a train once is enough to know what they are for.
	if sera.is_on_floor() and sera.get_last_slide_collision() != null and sera.get_last_slide_collision().get_collider() is Train:
		learn(&"train")
	var in_gust := false
	for gust in gusts:
		if gust.active() and gust.contains(sera.global_position):
			in_gust = true
	if in_gust:
		gust_felt = true
	elif gust_felt:
		learn(&"gust")
	# Chapter three: a lean ridden out, a field left behind, a red barrel jumped.
	if sway != null:
		if sway.is_leaning():
			tilt_felt = true
		elif tilt_felt and absf(sway.lean) < 0.05:
			learn(&"tilt")
	var in_field := false
	for field in fields:
		if field.holds_target():
			in_field = true
	if in_field:
		field_felt = true
	elif field_felt:
		learn(&"low_gravity")
	if not sera.is_on_floor():
		for rack in racks:
			for barrel: Dictionary in rack.barrels:
				if barrel["red"] and absf(rack.barrel_point(barrel).x - at.x) < 30.0 and at.y < rack.global_position.y - 20.0:
					learn(&"barrel_red")


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
		for turret in turrets:
			if turret.home.x < edge:
				turret.restore_defeated()
		for bomber in bombers:
			if bomber.home_x < edge:
				bomber.restore_defeated()
		for hatch in hatches:
			if hatch.position.x < edge:
				hatch.break_open(true)
		for launcher in launchers:
			if launcher.home.x < edge:
				launcher.restore_defeated()
		for absorber in absorbers:
			if absorber.home.x < edge:
				absorber.restore_defeated()
		for target in targets:
			if target.position.x < edge and target.hold_time <= 0.0:
				target.strike(true)
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
	for turret in turrets:
		if not turret.down:
			turret.reset_foe()
	for bomber in bombers:
		if not bomber.down:
			bomber.reset_foe()
	for gust in gusts:
		gust.restart()
	for train in trains:
		train.restart()
	for launcher in launchers:
		if not launcher.down:
			launcher.reset_foe()
	for absorber in absorbers:
		if not absorber.down:
			absorber.reset_foe()
	for rack in racks:
		rack.restart()
	for target in targets:
		target.restart()
	for field in fields:
		field.restart()
	if sway != null:
		sway.restart()
	gust_felt = false
	tilt_felt = false
	field_felt = false
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
	for turret in turrets:
		if turret.down or turret in wave_hits:
			continue
		if not _wave_reaches(turret.head_point(), Turret.HIT_RADIUS, next_distance) \
				and not _wave_reaches(turret.base_point(), Turret.HIT_RADIUS, next_distance):
			continue
		wave_hits.append(turret)
		if turret.mirror_blocks(wave_direction):
			_mirror_return(turret)
			continue
		turret.take_wave(push)
		learn(&"mirror" if turret.mirror else &"turret")
		effects.impact(turret.head_point(), true)
		_play(Audio.CORE_BREAK, -6.0, 0.95)
		_show_feedback(Texts.SECTOR_NOTE_MIRROR_DOWN if turret.mirror else Texts.SECTOR_NOTE_TURRET_DOWN, ICE)
		_hitstop(0.07, 8.0, 0.1, ICE)
	for launcher in launchers:
		if launcher.down or launcher in wave_hits or not _wave_reaches(launcher.hit_point(), Launcher.HIT_RADIUS, next_distance):
			continue
		wave_hits.append(launcher)
		launcher.glance()
		effects.impact(launcher.hit_point(), false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.SECTOR_NOTE_LAUNCHER_ARMOR, HEAT)
	for absorber in absorbers:
		if absorber.down or absorber in wave_hits or not _wave_reaches(absorber.chest_point(), 70.0, next_distance):
			continue
		wave_hits.append(absorber)
		absorber.drink(wave_origin.x)
		_show_feedback(Texts.SECTOR_NOTE_ABSORBED, HEAT)
	for rack in racks:
		for barrel: Dictionary in rack.barrels.duplicate():
			if barrel["fall"] == 0.0 and _wave_reaches(rack.barrel_point(barrel), 46.0, next_distance):
				rack.smash(barrel)
	for target in targets:
		if target in wave_hits or not _wave_reaches(target.global_position, ReflectTarget.HIT_RADIUS, next_distance):
			continue
		wave_hits.append(target)
		target.shake_plate()
		if not target.lit:
			_play(Audio.ARMOR, -6.0, 1.3)
			_show_feedback(Texts.SECTOR_NOTE_TARGET_SHOCK, HEAT)
	for bomber in bombers:
		if bomber.down or bomber in wave_hits or not _wave_reaches(bomber.hit_point(), Bomber.HIT_RADIUS, next_distance):
			continue
		wave_hits.append(bomber)
		bomber.take_wave(push)
		learn(&"bomber_down")
		effects.impact(bomber.hit_point(), true)
		_play(Audio.CORE_BREAK, -6.0, 1.05)
		_show_feedback(Texts.SECTOR_NOTE_BOMBER_DOWN, ICE)
		_hitstop(0.08, 9.0, 0.1, ICE)


## A downward release breaks the hatch it lands on, and whatever is under Sera
## within reach takes the wave as usual.
func _on_release(origin: Vector2, direction: Vector2) -> void:
	super._on_release(origin, direction)
	if direction.y < 0.5:
		return
	var ray := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0.0, WAVE_RANGE), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit["collider"] is Hatch:
		hit["collider"].break_open()


func _on_hatch_broken(origin: Vector2) -> void:
	learn(&"hatch")
	effects.impact(origin, true)
	_play(Audio.CORE_BREAK, -5.0, 0.78)
	_show_feedback(Texts.SECTOR_NOTE_HATCH, ICE)
	shake = maxf(shake, 7.0)
	deck_art.queue_redraw()


func _on_bomber_warning(_red: bool) -> void:
	_play(Audio.PRESS_CUE, -7.0, 1.2)


func _on_canister_caught(origin: Vector2, charge: int) -> void:
	learn(&"bomber_catch")
	caught_shots += 1
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -3.0, 1.1)
	_hitstop(0.07, 7.0, 0.1, ICE)
	_show_feedback(Texts.SECTOR_NOTE_CANISTER + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_canister_burst(point: Vector2, hit_player: bool) -> void:
	effects.impact(point, true)
	_play(Audio.IMPACT, -6.0, 1.1)
	shake = maxf(shake, 6.0)
	if not hit_player and absf(point.x - sera.position.x) < 300.0:
		learn(&"bomber_red")


func _on_guard_hit(guard: Guard) -> void:
	if guard.knocked_out and guard.front_guard:
		learn(&"front_guard")
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
	for bomber in bombers:
		if not bomber.down:
			candidates.append([bomber.global_position, Bomber.HIT_RADIUS])
	for turret in turrets:
		if not turret.down and turret.muzzle_height >= HIGH_MUZZLE:
			candidates.append([turret.head_point(), Turret.HIT_RADIUS])
	for target in targets:
		if not target.lit:
			candidates.append([target.global_position, ReflectTarget.HIT_RADIUS])
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
	# Each chapter explains only its own new machines.
	var hints := _chapter_three_hints() if Texts.chapter_of(stage_number()) >= 2 else _new_machine_hints()
	if not tutorial_stage():
		# Past chapter one only what is new gets explained, plus the story.
		hints.append_array(_story_hints())
		return hints
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
	hints.append_array(_story_hints())
	return hints


func _story_hints() -> Array:
	for line: Array in lines:
		if knows(line[1]):
			continue
		if sera.position.x >= line[0]:
			return [hint(line[1], Vector2.INF, [[[], line[2]]])]
		break
	return []


## Chapter two's machines and abilities, each explained the first time it matters.
func _new_machine_hints() -> Array:
	var hints := []
	var at := sera.global_position
	for turret in turrets:
		if turret.down or not turret.is_aiming() or absf(turret.global_position.x - at.x) > 640.0:
			continue
		if turret.muzzle_height >= HIGH_MUZZLE and sera.air_absorb and not knows(&"air_catch"):
			hints.append(hint(&"air_catch", turret.head_point(), spoken(Texts.SECTOR_HINT_AIR_CATCH, [["Space", "+", "LMB"]])))
		elif turret.muzzle_height < HIGH_MUZZLE and not knows(&"turret"):
			hints.append(hint(&"turret", turret.head_point(), spoken(Texts.SECTOR_HINT_TURRET, [["LMB"]])))
		break
	for bomber in bombers:
		if bomber.down or absf(bomber.global_position.x - at.x) > 520.0 or absf(bomber.floor_y - at.y) > 140.0:
			continue
		if bomber.is_locking():
			if bomber.next_is_red() and not knows(&"bomber_red"):
				hints.append(hint(&"bomber_red", bomber.global_position + Vector2(0.0, 60.0), spoken(Texts.SECTOR_HINT_BOMBER_RED), HEAT))
			elif not bomber.next_is_red() and not knows(&"bomber_catch"):
				hints.append(hint(&"bomber_catch", bomber.global_position + Vector2(0.0, 60.0), spoken(Texts.SECTOR_HINT_BOMBER_CATCH, [["LMB"]])))
		elif bomber.state == Bomber.State.DRIFT and sera.energy >= Sera.RELEASE_COST and not knows(&"bomber_down"):
			hints.append(hint(&"bomber_down", bomber.global_position, spoken(Texts.SECTOR_HINT_BOMBER_SHOT, [["W", "+", "RMB"]]), POWER))
		break
	for guard in guards:
		if guard.front_guard and not guard.knocked_out and not knows(&"front_guard") \
				and absf(guard.global_position.x - at.x) < 520.0 and absf(guard.global_position.y - at.y) < 170.0:
			hints.append(hint(&"front_guard", guard.global_position + Vector2(0.0, -210.0),
				spoken(Texts.SECTOR_HINT_FRONT_GUARD, [["S", "+", "RMB"]]), HEAT))
			break
	if sera.down_release and sera.energy >= Sera.RELEASE_COST:
		for hatch in hatches:
			if not hatch.open and not knows(&"hatch") and absf(hatch.global_position.x - at.x) < 220.0 \
					and absf(hatch.global_position.y - at.y) < 80.0:
				hints.append(hint(&"hatch", hatch.global_position + Vector2(0.0, -150.0), spoken(Texts.SECTOR_HINT_HATCH, [["S", "+", "RMB"]])))
				break
		for spot in down_spots:
			if not knows(&"release_down") and absf(spot.x - at.x) < 200.0 and absf(spot.y - at.y) < 80.0:
				hints.append(hint(&"release_down", spot + Vector2(0.0, -230.0), spoken(Texts.SECTOR_HINT_DOWN, [["S", "+", "RMB"]])))
				break
	if not knows(&"train"):
		for train in trains:
			var edge: float = train.home.x if at.x < train.home.x + train.span * 0.5 else train.home.x + train.span
			if absf(edge - at.x) < 260.0 and absf(train.home.y - at.y) < 60.0:
				hints.append(hint(&"train", Vector2(edge, train.home.y - 90.0), spoken(Texts.SECTOR_HINT_TRAIN, [[]])))
				break
	if not knows(&"gust"):
		for gust in gusts:
			if gust.active() and gust.contains(at):
				hints.append(hint(&"gust", Vector2.INF, spoken(Texts.SECTOR_HINT_GUST)))
				break
	return hints


func _on_shot_absorbed(origin: Vector2, charge: int, precise: bool) -> void:
	super._on_shot_absorbed(origin, charge, precise)
	learn(&"drone_shot")
	if not turrets.is_empty():
		learn(&"turret")


# ---------------------------------------------------------------- chapter three


## A shockwave met a mirror face head on: it comes straight back as a shot.
func _mirror_return(turret: Turret) -> void:
	turret.flash_mirror()
	var face := Vector2(turret.global_position.x + turret.facing * 64.0, wave_origin.y)
	var shot := fire_shot(face, turret.facing, false, false, turret)
	shot.echo = true
	effects.impact(face, false, false)
	_play(Audio.ARMOR, -3.0, 1.35)
	_show_feedback(Texts.SECTOR_NOTE_MIRROR, HEAT)


## What a reflected shot can strike in a sector: turrets (mirrors included),
## launchers, absorbers, wardens, drones, bombers, targets and relays.
func returned_hit(from: Vector2, to: Vector2, shot: Node2D) -> bool:
	var push := signf(to.x - from.x) if to.x != from.x else sera.facing
	var heavy: bool = shot.heavy
	for turret in turrets:
		if not turret.down and (crosses(from, to, turret.head_point(), Turret.HIT_RADIUS) or crosses(from, to, turret.base_point(), Turret.HIT_RADIUS)):
			turret.take_wave(push)
			learn(&"mirror" if turret.mirror else &"turret")
			_struck(turret.head_point(), Texts.SECTOR_NOTE_MIRROR_DOWN if turret.mirror else Texts.SECTOR_NOTE_TURRET_DOWN)
			return true
	for launcher in launchers:
		if not launcher.down and crosses(from, to, launcher.hit_point(), Launcher.HIT_RADIUS):
			launcher.take_hit(push)
			learn(&"launcher")
			_struck(launcher.hit_point(), Texts.SECTOR_NOTE_LAUNCHER_DOWN)
			return true
	for absorber in absorbers:
		if absorber.down or not crosses(from, to, absorber.chest_point(), Absorber.HIT_RADIUS):
			continue
		if heavy:
			absorber.take_hit(push)
			if absorber.down:
				learn(&"absorber")
				_struck(absorber.chest_point(), Texts.SECTOR_NOTE_ABSORBER_DOWN)
			else:
				effects.impact(absorber.chest_point(), true)
				_play(Audio.ARMOR, -3.0, 0.8)
				_show_feedback(Texts.NOTE_ARMOR_BROKEN, HEAT)
				_hitstop(0.07, 8.0, 0.1, ICE)
		else:
			absorber.drink(from.x)
			_show_feedback(Texts.SECTOR_NOTE_ABSORBED, HEAT)
		return true
	for guard in guards:
		if guard.knocked_out or not crosses(from, to, guard.global_position + Vector2(0.0, -75.0), 64.0):
			continue
		var hit_point := guard.global_position + Vector2(0.0, -68.0)
		if guard.shielded or guard.shield_blocks(Vector2(push, 0.0)):
			guard.flash_shield()
			effects.impact(hit_point, false)
			_play(Audio.ARMOR, -4.0)
			_show_feedback(Texts.NOTE_FRONT_SHIELD if guard.front_guard else Texts.NOTE_SHIELDED, HEAT)
			return true
		guard.knockback(push)
		effects.impact(hit_point, true)
		_on_guard_hit(guard)
		if guard.knocked_out:
			_save_progress()
		_hitstop(0.086, 10.5, 0.13, ICE)
		return true
	for drone in drones:
		if not drone.down and crosses(from, to, drone.hit_point(), drone.HIT_RADIUS):
			drone.take_wave(push)
			_struck(drone.hit_point(), Texts.SECTOR_NOTE_DRONE_DOWN)
			return true
	for bomber in bombers:
		if not bomber.down and crosses(from, to, bomber.hit_point(), Bomber.HIT_RADIUS):
			bomber.take_wave(push)
			_struck(bomber.hit_point(), Texts.SECTOR_NOTE_BOMBER_DOWN)
			return true
	for target in targets:
		if crosses(from, to, target.global_position, ReflectTarget.HIT_RADIUS) and (not target.lit or target.hold_time > 0.0):
			target.strike()
			return true
	for relay in relays:
		if not relay.powered and crosses(from, to, relay.global_position, relay.HIT_RADIUS):
			relay.energize()
			_save_progress()
			return true
	return false


func _struck(point: Vector2, message: String) -> void:
	effects.impact(point, true)
	effects.catch_shot(point, true)
	_play(Audio.CORE_BREAK, -5.0, 1.05)
	_show_feedback(message, GOLD)
	_hitstop(0.08, 9.0, 0.12, GOLD)
	deck_art.queue_redraw()


func _on_launcher_warning(_sweep: bool) -> void:
	_play(Audio.SHOT_CUE, -6.0, 0.8)


func _on_missile_launched(origin: Vector2, launcher: Launcher) -> void:
	var missile := Homing.new()
	missile.position = origin
	missile.player = sera
	missile.level = self
	missile.source = launcher
	missile.velocity = Vector2(launcher.facing * 0.45, -1.0).normalized() * Homing.SPEED
	missile.direction = launcher.facing
	missile.absorbed.connect(_on_missile_caught)
	missile.reflected.connect(_on_shot_reflected)
	missile.burst.connect(_on_missile_burst)
	launcher.missile = missile
	shots.add_child(missile)
	_play(Audio.LIFT, -7.0, 0.72)


func _on_missile_caught(origin: Vector2, charge: int, precise: bool) -> void:
	learn(&"homing")
	caught_shots += 1
	if precise:
		perfect_shots += 1
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.5, 1.15)
	_hitstop(0.08, 7.0, 0.11, ICE)
	_show_feedback(Texts.SECTOR_NOTE_MISSILE + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_missile_burst(origin: Vector2, _hit_player: bool) -> void:
	effects.impact(origin, true)
	if absf(origin.x - sera.position.x) < 700.0:
		_play(Audio.IMPACT, -8.0, 1.2)


func _on_echo_fired(origin: Vector2, direction: float, guard: Absorber) -> void:
	var shot := fire_shot(origin, direction, false, true, guard)
	shot.echo = true
	_play(Audio.SHOT, -4.0, 0.7)


func _on_absorber_drank(origin: Vector2) -> void:
	effects.catch_shot(origin, false)
	_play(Audio.HEAVY_CATCH, -5.0, 1.3)


func _on_barrel_caught(origin: Vector2, charge: int, precise: bool) -> void:
	learn(&"barrel")
	caught_shots += 1
	if precise:
		perfect_shots += 1
	effects.catch_energy(origin)
	_play(Audio.PRECISE_CATCH if precise else Audio.HEAVY_CATCH, -2.0, 0.95)
	_hitstop(0.09 if precise else 0.07, 8.0, 0.12, ICE)
	_show_feedback(Texts.SECTOR_NOTE_BARREL + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_barrel_smashed(origin: Vector2, _hit_player: bool) -> void:
	effects.impact(origin, true)
	_play(Audio.IMPACT, -6.0, 0.9)
	shake = maxf(shake, 4.0)


func _on_target_lit(origin: Vector2) -> void:
	learn(&"target")
	effects.catch_shot(origin, true)
	_play(Audio.RELAY, -3.0, 1.15)
	_show_feedback(Texts.SECTOR_NOTE_TARGET, GOLD)
	_hitstop(0.063, 4.0, 0.07, GOLD)
	deck_art.queue_redraw()


func _on_ship_leaning(side: float) -> void:
	for rack in racks:
		rack.let_go(side)
	shake = maxf(shake, 3.0)


func _on_ship_warned(_side: float) -> void:
	_play(Audio.IMPACT, -12.0, 0.55)


## The missile in the air nearest Sera, or null.
func _nearest_missile() -> Homing:
	var best: Homing
	for shot in shots.get_children():
		if shot is Homing and not shot.returned and (best == null or shot.global_position.distance_to(sera.global_position) < best.global_position.distance_to(sera.global_position)):
			best = shot
	return best


## Chapter three's machines and the reflect, each explained the first time it matters.
func _chapter_three_hints() -> Array:
	var hints := []
	var at := sera.global_position
	var reflect_keys := [["LMB", "+", "RMB"]]
	if sway != null and not knows(&"tilt") and (sway.warning() or sway.is_leaning()):
		hints.append(hint(&"tilt", Vector2.INF, spoken(Texts.SECTOR_HINT_TILT), HEAT))
	for rack in racks:
		for barrel: Dictionary in rack.barrels:
			var point := rack.barrel_point(barrel)
			if barrel["fall"] > 0.0 or absf(point.x - at.x) > 480.0 or absf(rack.global_position.y - at.y) > 40.0 \
					or signf(at.x - point.x) != barrel["side"]:
				continue
			if barrel["red"] and not knows(&"barrel_red"):
				hints.append(hint(&"barrel_red", point + Vector2(0.0, -40.0), spoken(Texts.SECTOR_HINT_BARREL_RED, [["Space"]]), HEAT))
			elif not barrel["red"] and not knows(&"barrel"):
				hints.append(hint(&"barrel", point + Vector2(0.0, -40.0), spoken(Texts.SECTOR_HINT_BARREL, [["LMB"]])))
			break
	var missile := _nearest_missile()
	if missile != null and not knows(&"homing") and missile.global_position.distance_to(at) < 700.0:
		hints.append(hint(&"homing", missile.global_position, spoken(Texts.SECTOR_HINT_HOMING, reflect_keys), HEAT))
	for absorber in absorbers:
		if not absorber.down and not knows(&"absorber") and absorber._engaged():
			hints.append(hint(&"absorber", absorber.chest_point() + Vector2(0.0, -40.0),
				spoken(Texts.SECTOR_HINT_ABSORBER_ECHO if absorber.is_charging() else Texts.SECTOR_HINT_ABSORBER, reflect_keys), HEAT))
			break
	for turret in turrets:
		if turret.down or absf(turret.global_position.x - at.x) > 640.0 or absf(turret.global_position.y - at.y) > 240.0:
			continue
		if turret.mirror and not knows(&"mirror"):
			hints.append(hint(&"mirror", turret.head_point(), spoken(Texts.SECTOR_HINT_MIRROR, reflect_keys), HEAT))
		elif sera.reflect and not knows(&"reflect") and turret.is_aiming():
			hints.append(hint(&"reflect", turret.head_point(), spoken(Texts.SECTOR_HINT_REFLECT, reflect_keys)))
		break
	for target in targets:
		if not target.lit and not knows(&"target") and absf(target.global_position.x - at.x) < 460.0 and at.y - target.global_position.y < 480.0:
			hints.append(hint(&"target", target.global_position, spoken(Texts.SECTOR_HINT_TARGET, [["LMB", "+", "W", "+", "RMB"]]), GOLD))
			break
	if not knows(&"low_gravity"):
		for field in fields:
			if field.holds_target():
				hints.append(hint(&"low_gravity", Vector2.INF, spoken(Texts.SECTOR_HINT_LOW_GRAVITY)))
				break
	if sera.reflect and not knows(&"reflect") and _incoming(false):
		hints.append(hint(&"reflect", Vector2.INF, spoken(Texts.SECTOR_HINT_REFLECT, reflect_keys)))
	return hints
