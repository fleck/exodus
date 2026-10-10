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
		_hill()
		return
	_rock()


func _rock() -> void:
	var colors: Array[Material] = [
		Figure.stone(Color(0.45, 0.37, 0.3)),
		Figure.stone(Color(0.55, 0.42, 0.3)),
		Figure.stone(Color(0.32, 0.28, 0.24)),
	]
	var main := Figure.add_mesh(self, Figure.sphere(1.0, 1.45, 16), Vector3(0, 0.5, 0), colors[0])
	main.scale = Vector3(1.55, 1.0, 1.25)
	var left := Figure.add_mesh(self, Figure.sphere(0.7, 0.95, 12), Vector3(-1.1, 0.32, 0.2), colors[1])
	left.scale = Vector3(1.15, 0.7, 0.95)
	var right := Figure.add_mesh(self, Figure.sphere(0.55, 0.75, 12), Vector3(0.95, 0.26, -0.35), colors[2])
	right.scale = Vector3(1.2, 0.55, 1.0)
	var cap := Figure.add_mesh(self, Figure.sphere(0.42, 0.5, 10), Vector3(0.2, 1.15, 0.05), colors[1])
	cap.scale = Vector3(1.15, 0.65, 0.85)
	Figure.add_mesh(self, Figure.box(Vector3(0.08, 0.85, 0.1)), Vector3(0.15, 0.65, 0.9), Figure.stone(Color(0.1, 0.08, 0.07)), Vector3(0, 10, 14), false)
	for i in 5:
		var bit := Figure.add_mesh(self, Figure.sphere(0.12 + float(i) * 0.015, 0.18, 8), Vector3(-0.85 + float(i) * 0.38, 0.08, 0.95), colors[i % 3], Vector3.ZERO, false)
		bit.scale = Vector3(1.25, 0.4, 0.9)


func _hill() -> void:
	var sand := Figure.stone(Color(0.64, 0.48, 0.32))
	var rock := Figure.stone(Color(0.5, 0.38, 0.28))
	var dark := Figure.stone(Color(0.4, 0.3, 0.22))
	var mass := Figure.add_mesh(self, Figure.sphere(1, 2, 14), Vector3(0, -0.6, -4), sand)
	mass.scale = Vector3(8.5, 2.8, 6.6)
	var shoulder := Figure.add_mesh(self, Figure.sphere(1, 2, 12), Vector3(-3.6, -0.35, -1.2), sand)
	shoulder.scale = Vector3(4.4, 1.8, 3.3)
	var far := Figure.add_mesh(self, Figure.sphere(1, 2, 12), Vector3(3.4, -0.5, -6.2), dark)
	far.scale = Vector3(3.8, 1.6, 2.9)
	var outcrop := Figure.add_mesh(self, Figure.sphere(0.8, 1.05, 10), Vector3(1.3, 1.15, -3.0), rock)
	outcrop.scale = Vector3(1.5, 0.65, 1.1)
	var rib := Figure.add_mesh(self, Figure.sphere(0.5, 0.7, 8), Vector3(-1.6, 0.85, -5.0), rock)
	rib.scale = Vector3(1.35, 0.5, 0.9)
	var mark := _pillar(Color(0.95, 0.82, 0.48))
	mark.position = Vector3(0, 0.3, 0)
	add_child(mark)


func _pillar(color: Color) -> Node3D:
	var root := Node3D.new()
	var core := _glow_column(0.1, 0.22, 7.0, color, 0.45)
	core.position.y = 3.6
	root.add_child(core)
	var haze := _glow_column(0.4, 0.85, 6.0, color, 0.12)
	haze.position.y = 3.2
	root.add_child(haze)
	return root


func _glow_column(top: float, bottom: float, height: float, color: Color, alpha: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = height
	cyl.radial_segments = 12
	mesh.mesh = cyl
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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
