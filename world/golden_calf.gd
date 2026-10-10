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
	var gold := Figure.metal(Color(0.92, 0.74, 0.28), 0.28, 0.14)
	var gold_dark := Figure.metal(Color(0.58, 0.42, 0.14), 0.4, 0.05)
	var stone := Figure.stone(Color(0.46, 0.4, 0.34))
	var eye := Figure.hair(Color(0.08, 0.05, 0.04))
	Figure.add_mesh(self, Figure.cylinder(0.9, 1.05, 0.28, 16), Vector3(0, 0.14, 0), stone)
	Figure.add_mesh(self, Figure.cylinder(0.72, 0.78, 0.08, 14), Vector3(0, 0.3, 0), gold_dark)
	var body := Figure.add_mesh(self, Figure.capsule(0.28, 1.15, 16), Vector3(-0.05, 0.82, 0), gold)
	body.rotation_degrees = Vector3(0, 0, 90)
	Figure.span(self, Vector3(0.4, 0.9, 0), Vector3(0.72, 1.18, 0), 0.11, gold)
	Figure.add_mesh(self, Figure.sphere(0.2, 0.34, 16), Vector3(0.84, 1.26, 0), gold)
	var snout := Figure.add_mesh(self, Figure.sphere(0.1, 0.16, 12), Vector3(1.05, 1.16, 0), gold)
	snout.scale = Vector3(1.35, 0.7, 0.8)
	var ear_l := Figure.add_mesh(self, Figure.sphere(0.06, 0.1, 8), Vector3(0.78, 1.38, 0.12), gold, Vector3.ZERO, false)
	ear_l.scale = Vector3(0.4, 1.2, 0.65)
	var ear_r := Figure.add_mesh(self, Figure.sphere(0.06, 0.1, 8), Vector3(0.78, 1.38, -0.12), gold, Vector3.ZERO, false)
	ear_r.scale = Vector3(0.4, 1.2, 0.65)
	Figure.add_mesh(self, Figure.cylinder(0.0, 0.035, 0.28, 6), Vector3(0.74, 1.48, 0.07), gold, Vector3(0, 0, 28), false)
	Figure.add_mesh(self, Figure.cylinder(0.0, 0.035, 0.28, 6), Vector3(0.74, 1.48, -0.07), gold, Vector3(0, 0, -28), false)
	Figure.add_mesh(self, Figure.sphere(0.018, 0.03, 6), Vector3(0.98, 1.28, 0.07), eye, Vector3.ZERO, false)
	Figure.add_mesh(self, Figure.sphere(0.018, 0.03, 6), Vector3(0.98, 1.28, -0.07), eye, Vector3.ZERO, false)
	var hoof := Figure.metal(Color(0.34, 0.26, 0.14), 0.48)
	for x in [0.28, -0.38]:
		for z in [0.14, -0.14]:
			Figure.add_mesh(self, Figure.cylinder(0.055, 0.07, 0.5, 8), Vector3(x, 0.42, z), gold)
			Figure.add_mesh(self, Figure.sphere(0.05, 0.055, 8), Vector3(x, 0.16, z), hoof, Vector3.ZERO, false)
	Figure.span(self, Vector3(-0.58, 0.82, 0), Vector3(-0.78, 0.42, 0.04), 0.022, gold)
	Figure.add_mesh(self, Figure.sphere(0.055, 0.09, 8), Vector3(-0.8, 0.38, 0.05), gold_dark, Vector3.ZERO, false)
