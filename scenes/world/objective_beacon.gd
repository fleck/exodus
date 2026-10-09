extends Node3D

var _spin: Node3D
var _shown := false


func _ready() -> void:
	_spin = Node3D.new()
	add_child(_spin)
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.18
	cyl.height = 14.0
	column.mesh = cyl
	column.position.y = 7.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.82, 0.4, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	column.material_override = mat
	_spin.add_child(column)
	EventBus.mission_started.connect(func(_mission: Resource) -> void: _place())
	call_deferred("_place")


func _process(delta: float) -> void:
	if _shown:
		_spin.rotate_y(delta * 0.4)


func _place() -> void:
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	if missions == null or missions.active_mission == null:
		visible = false
		_shown = false
		return
	global_position = missions.active_mission.objective_coordinates
	visible = true
	_shown = true
