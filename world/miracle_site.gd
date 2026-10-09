class_name MiracleSite
extends Node3D

@export var site_id: String = "rock"
@export var grants_water: bool = true

var progress: float = 0.0


func _ready() -> void:
	add_to_group("miracle_site")
	_build()


func _process(delta: float) -> void:
	if NetworkManager.online() and not multiplayer.is_server():
		return
	var moses := SessionManager.leader(&"Moses") as CoopController
	var sim := get_tree().get_first_node_in_group("camp") as CampSimulation
	var channeling := (
		moses != null
		and moses.is_channeling
		and global_position.distance_to(moses.global_position) <= 4.0
	)
	if not channeling:
		progress = maxf(0.0, progress - delta)
		return
	if not grants_water or sim == null or not sim.rock_ready:
		return
	progress += delta
	if progress >= 2.6:
		progress = 0.0
		sim.grant_spring()
		_flash()


func _build() -> void:
	if site_id == "hill":
		var mound := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		mound.mesh = sphere
		mound.scale = Vector3(7.0, 2.4, 6.0)
		mound.position = Vector3(0, 0.4, -6)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.48, 0.32)
		mat.roughness = 1.0
		mound.material_override = mat
		add_child(mound)
		var mark := _pillar(Color(0.85, 0.75, 0.45))
		mark.position.y = 0.2
		add_child(mark)
		return
	var rock := MeshInstance3D.new()
	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 1.0
	stone_mesh.height = 1.6
	rock.mesh = stone_mesh
	rock.scale = Vector3(1.4, 1.1, 1.2)
	rock.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.36, 0.32)
	mat.roughness = 0.88
	rock.material_override = mat
	add_child(rock)


func _pillar(color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 3.2
	mesh.mesh = cyl
	mesh.position.y = 1.6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	return mesh


func _flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.95, 1.0)
	light.light_energy = 12.0
	light.omni_range = 16.0
	light.position.y = 1.5
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.45)
	tween.tween_callback(light.queue_free)
