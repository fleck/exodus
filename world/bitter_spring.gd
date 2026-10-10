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
	var pale := Figure.stone(Color(0.58, 0.5, 0.4))
	var stone := Figure.stone(Color(0.42, 0.36, 0.3))
	var dark := Figure.stone(Color(0.3, 0.26, 0.22))
	for i in 12:
		var angle := float(i) / 12.0 * TAU
		var radius := 3.55 + (0.28 if i % 2 == 0 else 0.0)
		var rock := Figure.add_mesh(self, Figure.sphere(0.42, 0.62, 10), Vector3(cos(angle) * radius, 0.16, sin(angle) * radius), pale if i % 3 == 0 else stone)
		rock.scale = Vector3(1.15 + float(i % 3) * 0.12, 0.5 + float(i % 2) * 0.18, 0.95)
		rock.rotation_degrees = Vector3(0, rad_to_deg(angle), float(i % 4) * 7.0)
	Figure.add_mesh(self, Figure.sphere(0.7, 0.5, 10), Vector3(2.2, 0.12, 1.4), dark).scale = Vector3(1.4, 0.45, 1.1)
	Figure.add_mesh(self, Figure.sphere(0.55, 0.4, 8), Vector3(-2.6, 0.1, -0.8), stone).scale = Vector3(1.2, 0.4, 1.0)
	var reed := Figure.cloth(Color(0.34, 0.42, 0.2), 0.82)
	var dry := Figure.cloth(Color(0.5, 0.44, 0.24), 0.86)
	for i in 8:
		var angle := float(i) * 0.8 + 0.3
		Figure.add_mesh(self, Figure.cylinder(0.008, 0.016, 0.75, 5), Vector3(cos(angle) * 2.6, 0.36, sin(angle) * 2.6), reed if i % 2 == 0 else dry, Vector3(5, 0, 8), false)


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
