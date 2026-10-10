extends Node3D

var _spin: Node3D
var _shown := false


func _ready() -> void:
	_spin = Node3D.new()
	add_child(_spin)
	var core := _shaft(0.07, 0.12, 12.0, Color(0.98, 0.9, 0.55, 0.5), 1.3)
	core.position.y = 6.0
	_spin.add_child(core)
	var haze := _shaft(0.35, 0.7, 10.0, Color(0.95, 0.8, 0.42, 0.1), 0.55)
	haze.position.y = 5.2
	_spin.add_child(haze)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.95
	torus.rings = 8
	torus.ring_segments = 14
	ring.mesh = torus
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _shaft_mat(Color(0.96, 0.84, 0.4, 0.8), 1.1)
	add_child(ring)
	EventBus.mission_started.connect(func(_mission: Resource) -> void: _place())
	call_deferred("_place")


func _process(delta: float) -> void:
	if _shown:
		_spin.rotate_y(delta * 0.35)


func _place() -> void:
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	if missions == null or missions.active_mission == null:
		visible = false
		_shown = false
		return
	global_position = missions.active_mission.objective_coordinates
	visible = true
	_shown = true


func _shaft(top: float, bottom: float, height: float, color: Color, energy: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = height
	cyl.radial_segments = 12
	mesh.mesh = cyl
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = _shaft_mat(color, energy)
	return mesh


func _shaft_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
