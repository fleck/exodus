class_name CrowdLod
extends Node3D
## Near the leaders, a few of the camp are real bodies.
## Past 35 meters they are a vertex-animated MultiMesh.

const NEAR_DISTANCE := 35.0
const PEOPLE := 72
const BODY_POOL := 10

var _slots: Array[Dictionary] = []
var _bodies: Array[CharacterBody3D] = []
var _multi: MultiMeshInstance3D
var _mesh: MultiMesh
var _riot := 0.0


func _ready() -> void:
	_build_slots()
	_build_multi()
	_build_pool()
	EventBus.riot_triggered.connect(func(_at: Vector3) -> void: _riot = 1.0)
	EventBus.riot_ended.connect(func() -> void: _riot = 0.0)


func _process(delta: float) -> void:
	var focus: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group("leaders"):
		if node is Node3D:
			focus.append((node as Node3D).global_position)
	if focus.is_empty():
		focus.append(Vector3.ZERO)
	var far_index := 0
	var body_index := 0
	for slot in _slots:
		var home: Vector3 = slot["home"]
		var phase: float = slot["phase"]
		var wander := Vector3(sin(Time.get_ticks_msec() * 0.0004 + phase) * 1.4, 0, cos(Time.get_ticks_msec() * 0.00033 + phase) * 1.4)
		var pos := home + wander
		var near := false
		for point in focus:
			if point.distance_to(pos) < NEAR_DISTANCE:
				near = true
				break
		if near and body_index < _bodies.size():
			var body := _bodies[body_index]
			body.visible = true
			var before := body.global_position
			if before.y < -1.0:
				body.global_position = pos
			else:
				body.global_position = before.lerp(pos, minf(1.0, delta * 2.0))
				var step := body.global_position - before
				if step.length_squared() > 0.00005:
					body.rotation.y = atan2(step.x, step.z)
			var rig: Dictionary = body.get_meta("rig")
			Figure.pose(rig, Time.get_ticks_msec() * 0.001 + float(body_index) * 0.37, 0.65, "")
			body_index += 1
		elif far_index < _mesh.instance_count:
			var stature := 0.9 + phase * 0.14
			var basis := Basis(Vector3.UP, phase * TAU).scaled(Vector3(stature, stature, stature))
			_mesh.set_instance_transform(far_index, Transform3D(basis, pos + Vector3(0, -0.06, 0)))
			far_index += 1
	_mesh.visible_instance_count = far_index
	if _multi.material_override is ShaderMaterial:
		(_multi.material_override as ShaderMaterial).set_shader_parameter("riot", _riot)
	while body_index < _bodies.size():
		_bodies[body_index].visible = false
		_bodies[body_index].global_position = Vector3(0, -20, 0)
		body_index += 1


func _build_slots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 40
	for i in PEOPLE:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(12.0, 30.0)
		_slots.append({
			"home": Vector3(cos(angle) * dist, 0.0, sin(angle) * dist),
			"phase": rng.randf(),
		})


func _build_multi() -> void:
	_mesh = MultiMesh.new()
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_colors = false
	_mesh.use_custom_data = false
	_mesh.mesh = Figure.distant_mesh()
	_mesh.instance_count = PEOPLE
	_mesh.visible_instance_count = 0
	_multi = MultiMeshInstance3D.new()
	_multi.multimesh = _mesh
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/crowd_walk.gdshader")
	_multi.material_override = mat
	add_child(_multi)


func _build_pool() -> void:
	for i in BODY_POOL:
		var body := CharacterBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1
		var shape_node := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.5
		shape_node.shape = capsule
		shape_node.position.y = 0.75
		body.add_child(shape_node)
		var visual := Node3D.new()
		visual.name = "Visual"
		var robe: Color = Figure.ROBE_COLORS[i % Figure.ROBE_COLORS.size()]
		var tone: Color = Figure.SKIN_COLORS[i % Figure.SKIN_COLORS.size()]
		var rig := Figure.build(visual, &"villager", robe, robe.darkened(0.28), tone, i)
		visual.scale = Vector3.ONE * (0.92 + float(i % 4) * 0.03)
		body.add_child(visual)
		body.set_meta("rig", rig)
		body.visible = false
		add_child(body)
		_bodies.append(body)
