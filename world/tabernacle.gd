class_name Tabernacle
extends CampInteractable

var progress: float = 0.0
var _accepted := false


func _ready() -> void:
	super._ready()
	add_to_group("tabernacle")
	_build()


func _process(delta: float) -> void:
	if NetworkManager.online() and not multiplayer.is_server():
		return
	var aaron := SessionManager.leader(&"Aaron") as CoopController
	if aaron == null:
		return
	var offering := aaron.is_performing_ritual and global_position.distance_to(aaron.global_position) < 3.6
	if not offering:
		progress = 0.0
		_accepted = false
		return
	progress += delta
	if progress < 2.3 or _accepted:
		return
	_accepted = true
	var sim := camp()
	if sim == null:
		return
	if sim.riot_active:
		sim.announce("The offering will not take while the camp riots.")
		progress = 0.0
		_accepted = false
		aaron.set_ritual_cooldown(4.0)
		return
	sim.add_murmuring(-16.0, "Aaron burned incense, and the camp grew quiet.")
	sim.disrupt_idolatry(35.0)
	EventBus.objective_event.emit(&"ritual")
	aaron.set_ritual_cooldown(18.0)


func can_use(by: Node) -> bool:
	if str(by.get("character_name")) != "Aaron":
		return false
	var sim := camp()
	return sim == null or not sim.riot_active


func prompt_for(by: Node) -> String:
	if str(by.get("character_name")) != "Aaron":
		return "Only Aaron offers the incense"
	if not can_use(by):
		return "The elders refuse an offering during the riot"
	return "Offer incense"


func interact(by: Node) -> bool:
	if not can_use(by):
		return false
	by.call("begin_ritual")
	return true


func _build() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.35, 0.18, 0.42)
	cloth.roughness = 0.75
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.78, 0.62, 0.28)
	gold.metallic = 0.85
	gold.roughness = 0.32
	var linen := StandardMaterial3D.new()
	linen.albedo_color = Color(0.9, 0.88, 0.8)
	linen.roughness = 0.8

	var tent := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.2, 2.4, 6.4)
	tent.mesh = box
	tent.position = Vector3(0, 1.3, 0)
	tent.material_override = cloth
	add_child(tent)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(4.6, 0.18, 6.8)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 2.55, 0)
	roof.material_override = gold
	add_child(roof)

	var altar := MeshInstance3D.new()
	var altar_mesh := BoxMesh.new()
	altar_mesh.size = Vector3(1.1, 0.8, 1.1)
	altar.mesh = altar_mesh
	altar.position = Vector3(0, 0.4, 1.6)
	altar.material_override = gold
	add_child(altar)

	var curtain := MeshInstance3D.new()
	var curtain_mesh := BoxMesh.new()
	curtain_mesh.size = Vector3(1.4, 2.0, 0.08)
	curtain.mesh = curtain_mesh
	curtain.position = Vector3(0, 1.1, 3.15)
	curtain.material_override = linen
	add_child(curtain)

	for x in [-2.4, 2.4]:
		for z in [-3.4, 3.4]:
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.08
			post_mesh.bottom_radius = 0.08
			post_mesh.height = 2.2
			post.mesh = post_mesh
			post.position = Vector3(x, 1.1, z)
			post.material_override = gold
			add_child(post)

	var lamp := AreaLight3D.new()
	lamp.name = "TabernacleLamp"
	lamp.area_size = Vector2(2.4, 1.2)
	lamp.area_range = 7.0
	lamp.area_attenuation = 1.4
	lamp.light_color = Color(1.0, 0.78, 0.42)
	lamp.light_energy = 1.6
	lamp.light_size = 0.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 2.2, 0)
	lamp.rotation_degrees = Vector3(-90, 0, 0)
	add_child(lamp)
	lamp.add_to_group("campfire_light")
