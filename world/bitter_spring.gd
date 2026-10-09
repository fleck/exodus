class_name BitterSpring
extends CampInteractable

var _mat: ShaderMaterial


func _ready() -> void:
	super._ready()
	add_to_group("spring")
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.2
	disc.bottom_radius = 3.2
	disc.height = 0.12
	mesh.mesh = disc
	mesh.position.y = 0.08
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/water.gdshader")
	_mat.set_shader_parameter("bitter", 1.0)
	mesh.material_override = _mat
	add_child(mesh)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.0
	torus.outer_radius = 3.6
	rim.mesh = torus
	rim.position.y = 0.12
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.45, 0.4, 0.34)
	stone.roughness = 0.9
	rim.material_override = stone
	add_child(rim)


func _process(_delta: float) -> void:
	var sim := camp()
	if sim == null or _mat == null:
		return
	_mat.set_shader_parameter("bitter", 0.0 if sim.marah_purified else 1.0)


func prompt_for(by: Node) -> String:
	var sim := camp()
	if sim and sim.marah_purified:
		return "Draw water" if sim.marah_draws > 0 else "The pool is resting"
	if str(by.get("character_name")) == "Miriam":
		return "Purify the bitter water"
	if sim and sim.wood > 0:
		return "Sweeten the water with wood"
	return "The water is bitter"


func interact(by: Node) -> bool:
	var sim := camp()
	if sim == null:
		return false
	return sim.purify_marah(str(by.get("character_name")))
