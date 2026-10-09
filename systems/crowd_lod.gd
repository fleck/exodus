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
			body.global_position = body.global_position.lerp(pos, minf(1.0, delta * 2.0))
			body_index += 1
		elif far_index < _mesh.instance_count:
			var basis := Basis.IDENTITY.scaled(Vector3(0.42, 0.95, 0.42))
			_mesh.set_instance_transform(far_index, Transform3D(basis, pos + Vector3(0, 0.9, 0)))
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
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.15
	_mesh = MultiMesh.new()
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_custom_data = false
	_mesh.instance_count = PEOPLE
	_mesh.visible_instance_count = 0
	_mesh.mesh = capsule
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
		var mesh := MeshInstance3D.new()
		var vis := CapsuleMesh.new()
		vis.radius = 0.32
		vis.height = 1.4
		mesh.mesh = vis
		mesh.position.y = 0.85
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = Color(0.48, 0.32, 0.22)
		cloth.roughness = 0.9
		mesh.material_override = cloth
		body.add_child(mesh)
		body.visible = false
		add_child(body)
		_bodies.append(body)
