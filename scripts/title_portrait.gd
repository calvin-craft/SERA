extends Node2D

const LOOK_AHEAD_TIME := 5.0
const WRIST_CHECK_TIME := 4.18
const CYCLE := LOOK_AHEAD_TIME + WRIST_CHECK_TIME
const FORWARD_PORTRAIT := preload("res://assets/characters/sera_title.png")
const GAZE_SHADER := preload("res://assets/characters/sera_title_gaze.gdshader")
const ROW_HEIGHT := 20.0
const ARM_COLUMNS := 24
const SEAM_COLUMNS := 4
const BODY_COLUMNS := 27
const HIPS := Vector2(629, 836)
const CHEST := Vector2(600, 523)
const NECK := Vector2(561, 349)
const HAIR_TIE := Vector2(609, 122)
const SHOULDER := Vector2(504, 478)
const ELBOW := Vector2(442, 722)
const WRIST := Vector2(310, 646)
const EMITTER := Vector2(340, 633)

# Source pixels (x, y, half-width) along the forearm's inside silhouette and elbow.
const FOREARM_SEAM := [
	Vector3(387, 594, 16), Vector3(377, 620, 15), Vector3(395, 642, 18),
	Vector3(414, 653, 12), Vector3(429, 665, 4.5), Vector3(429, 674, 16),
	Vector3(434, 693, 31), Vector3(440, 722, 36), Vector3(440, 753, 29),
	Vector3(415, 783, 15),
]

var chest: Bone2D
var head: Bone2D
var hair: Bone2D
var upper_arm: Bone2D
var forearm: Bone2D
var hand: Bone2D
var emitter: Sprite2D
var gaze_material := ShaderMaterial.new()

@onready var skin: Polygon2D = $Skin


func _ready() -> void:
	var rig := Skeleton2D.new()
	rig.name = "Rig"
	add_child(rig)
	var hips := _joint(rig, &"Hips", HIPS)
	chest = _joint(hips, &"Chest", CHEST - HIPS)
	head = _joint(chest, &"Head", NECK - CHEST)
	hair = _joint(head, &"Ponytail", HAIR_TIE - NECK)
	upper_arm = _joint(chest, &"UpperArm", SHOULDER - CHEST)
	forearm = _joint(upper_arm, &"Forearm", ELBOW - SHOULDER)
	hand = _joint(forearm, &"Hand", WRIST - ELBOW)
	_bind_skin(rig, [hips, chest, head, hair, upper_arm, forearm, hand])
	emitter = _make_emitter()
	gaze_material.shader = GAZE_SHADER
	gaze_material.set_shader_parameter(&"forward_portrait", FORWARD_PORTRAIT)
	skin.material = gaze_material
	pose_at(0.0)


func pose_at(seconds: float) -> void:
	var check_time := fposmod(seconds, CYCLE) - LOOK_AHEAD_TIME
	var breath := sin(seconds * TAU / 3.85)
	var lift := _gesture(check_time, 0.0, 1.34, 2.66, WRIST_CHECK_TIME)
	var turn := _gesture(check_time, 0.29, 1.44, 2.60, 3.92)
	var glance := _gesture(check_time, 0.38, 1.48, 2.56, 3.67)
	var ponytail_follow := _gesture(check_time, 0.53, 1.73, 2.69, 3.87)
	var eyes_down := _gesture(check_time, 0.47, 0.82, 2.73, 3.08)

	chest.position = CHEST - HIPS + Vector2(0.0, -2.4 * breath - 1.8 * lift)
	chest.rotation = 0.008 * breath
	head.rotation = 0.32 * (1.0 - glance) - 0.008 * breath
	hair.rotation = 0.015 * sin(seconds * 1.36 - 0.5) + 0.062 * ponytail_follow
	upper_arm.rotation = -0.052 * (1.0 - lift) + 0.007 * breath
	gaze_material.set_shader_parameter(&"look_ahead", 1.0 - eyes_down)

	# Foreshorten the brace across the arm as the hand rolls; its length stays fixed.
	var axis := Transform2D((WRIST - ELBOW).angle(), Vector2.ZERO)
	var roll := Transform2D(Vector2.RIGHT, Vector2.DOWN * lerpf(0.72, 1.0, turn), Vector2.ZERO)
	var lift_pose := Transform2D(-0.87 * (1.0 - lift), ELBOW - SHOULDER)
	forearm.transform = lift_pose * axis * roll * axis.inverse()
	hand.rotation = -0.12 * (1.0 - turn) + 0.009 * sin(seconds * 1.75)
	emitter.self_modulate.a = 0.09 + 0.49 * turn * glance


func _gesture(phase: float, start: float, raised: float, lower: float, rest: float) -> float:
	return smoothstep(start, raised, phase) * (1.0 - smoothstep(lower, rest, phase))


func _joint(parent: Node2D, joint_name: StringName, rest_position: Vector2) -> Bone2D:
	var joint := Bone2D.new()
	joint.name = joint_name
	joint.set_autocalculate_length_and_angle(false)
	joint.rest = Transform2D(0.0, rest_position)
	joint.apply_rest()
	parent.add_child(joint)
	return joint


func _bind_skin(rig: Skeleton2D, joints: Array[Bone2D]) -> void:
	var texture_size := skin.texture.get_size()
	var columns := ARM_COLUMNS + SEAM_COLUMNS + BODY_COLUMNS
	var stride := columns + 1
	var rows := ceili(texture_size.y / ROW_HEIGHT)
	var row_positions := PackedFloat32Array()
	for row in rows + 1:
		row_positions.append(float(row) / rows * texture_size.y)
	for edge in FOREARM_SEAM:
		row_positions.append(edge.y)
	row_positions.sort()

	var points := PackedVector2Array()
	var faces: Array[PackedInt32Array] = []
	for row in row_positions.size():
		var y := row_positions[row]
		var seam := _forearm_seam_at(y)
		for column in columns + 1:
			# Sample both sides of the gap so the sleeve never drags the torso.
			var x: float
			if column <= ARM_COLUMNS:
				x = lerpf(0.0, seam.x - seam.y, float(column) / ARM_COLUMNS)
			elif column <= ARM_COLUMNS + SEAM_COLUMNS:
				x = lerpf(seam.x - seam.y, seam.x + seam.y, float(column - ARM_COLUMNS) / SEAM_COLUMNS)
			else:
				x = lerpf(seam.x + seam.y, texture_size.x, float(column - ARM_COLUMNS - SEAM_COLUMNS) / BODY_COLUMNS)
			points.append(Vector2(x, y))
			if row < row_positions.size() - 1 and column < columns:
				var first := row * stride + column
				faces.append(PackedInt32Array([first, first + 1, first + stride + 1, first + stride]))

	var weights: Array[PackedFloat32Array] = []
	for _index in joints.size():
		var weight := PackedFloat32Array()
		weight.resize(points.size())
		weights.append(weight)
	for index in points.size():
		var influence := _weights_at(points[index])
		for joint in joints.size():
			weights[joint][index] = influence[joint]

	skin.polygon = points
	skin.uv = points
	skin.polygons = faces
	skin.skeleton = skin.get_path_to(rig)
	for index in joints.size():
		skin.add_bone(rig.get_path_to(joints[index]), weights[index])


func _weights_at(point: Vector2) -> PackedFloat32Array:
	var hair_edge := lerpf(608.0, 759.0, smoothstep(169.0, 412.0, point.y))
	var tail := smoothstep(hair_edge - 15.0, hair_edge + 25.0, point.x)
	tail *= 1.0 - smoothstep(410.0, 477.0, point.y)
	var neckline := lerpf(378.0, 342.0, smoothstep(512.0, 670.0, point.x))
	var face := (1.0 - tail) * (1.0 - smoothstep(neckline - 7.0, neckline + 39.0, point.y))

	var body_and_arm := 1.0 - tail - face
	var seam := _forearm_seam_at(point.y)
	var forearm_weight := body_and_arm * (1.0 - smoothstep(seam.x - seam.y, seam.x + seam.y, point.x))
	forearm_weight *= smoothstep(576.0, 606.0, point.y) * (1.0 - smoothstep(740.0, 783.0, point.y))
	var arm_direction := ELBOW.direction_to(WRIST)
	var hand_weight := forearm_weight * smoothstep(-15.0, 30.0, (point - WRIST).dot(arm_direction))

	var sleeve := (body_and_arm - forearm_weight) * (1.0 - smoothstep(510.0, 597.0, point.x))
	sleeve *= smoothstep(397.0, 459.0, point.y) * (1.0 - smoothstep(751.0, 817.0, point.y))
	var body := body_and_arm - forearm_weight - sleeve
	var torso := body * (1.0 - smoothstep(640.0, 858.0, point.y))
	return PackedFloat32Array([
		body - torso, torso, face, tail,
		sleeve, forearm_weight - hand_weight, hand_weight,
	])


func _forearm_seam_at(y: float) -> Vector2:
	for index in range(1, FOREARM_SEAM.size()):
		var previous: Vector3 = FOREARM_SEAM[index - 1]
		var next: Vector3 = FOREARM_SEAM[index]
		if y < next.y:
			var blend := clampf(inverse_lerp(previous.y, next.y, y), 0.0, 1.0)
			return Vector2(lerpf(previous.x, next.x, blend), lerpf(previous.z, next.z, blend))
	return Vector2(FOREARM_SEAM.back().x, FOREARM_SEAM.back().z)


func _make_emitter() -> Sprite2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.35, 0.90, 1.0, 0.53), Color(0.10, 0.59, 0.78, 0.30), Color(0.10, 0.52, 0.74, 0.0),
	])
	var halo := GradientTexture2D.new()
	halo.gradient = gradient
	halo.width = 88
	halo.height = 88
	halo.fill = GradientTexture2D.FILL_RADIAL
	halo.fill_from = Vector2(0.5, 0.5)
	halo.fill_to = Vector2(1.0, 0.5)
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var light := Sprite2D.new()
	light.name = "Emitter"
	light.texture = halo
	light.material = blend
	light.position = EMITTER - ELBOW
	forearm.add_child(light)
	return light
