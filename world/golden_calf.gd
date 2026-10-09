class_name GoldenCalf
extends Node3D

func _ready() -> void:
	add_to_group("calf")
	visible = false
	_build()


func _process(_delta: float) -> void:
	var sim := get_tree().get_first_node_in_group("camp") as CampSimulation
	if sim == null:
		return
	visible = sim.idolatry_active
	if not visible:
		return
	var grow := 0.35 + clampf(sim.idolatry_progress / 100.0, 0.0, 1.0) * 1.15
	scale = Vector3.ONE * grow


func strike(amount: float) -> void:
	var sim := get_tree().get_first_node_in_group("camp") as CampSimulation
	if sim:
		sim.disrupt_idolatry(amount * 0.5)


func prompt_for(_by: Node) -> String:
	return "Strike the calf"


func _build() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.92, 0.72, 0.22)
	gold.metallic = 1.0
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Color(0.6, 0.4, 0.05)
	gold.emission_energy_multiplier = 0.25
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.8, 0.7)
	body.mesh = box
	body.position.y = 0.7
	body.material_override = gold
	add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	head.mesh = sphere
	head.position = Vector3(0.55, 1.15, 0)
	head.material_override = gold
	add_child(head)
	for x in [-0.35, 0.35]:
		var leg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.08
		cyl.height = 0.55
		leg.mesh = cyl
		leg.position = Vector3(x, 0.28, 0.2)
		leg.material_override = gold
		add_child(leg)
