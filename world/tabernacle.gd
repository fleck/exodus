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
	var linen := Figure.cloth(Color(0.9, 0.88, 0.8))
	var linen_dim := Figure.cloth(Color(0.75, 0.7, 0.6))
	var skins := Figure.leather(Color(0.5, 0.26, 0.16))
	var skins_dark := Figure.leather(Color(0.32, 0.16, 0.1))
	var gold := Figure.metal(Color(0.82, 0.66, 0.28), 0.3, 0.06)
	var bronze := Figure.metal(Color(0.62, 0.4, 0.22), 0.42)
	var grate := Figure.metal(Color(0.32, 0.24, 0.18), 0.5)
	var acacia := Figure.wood(Color(0.42, 0.28, 0.16))

	for x in [-1.7, 1.7]:
		for z in [-2.5, -1.25, 0.0, 1.25, 2.5]:
			Figure.add_mesh(self, Figure.cylinder(0.055, 0.065, 2.45, 8), Vector3(x, 1.22, z), gold)
			Figure.add_mesh(self, Figure.cylinder(0.04, 0.045, 2.2, 6), Vector3(x * 0.72, 1.1, z), acacia, Vector3.ZERO, false)
	Figure.add_mesh(self, Figure.box(Vector3(3.15, 2.1, 0.05)), Vector3(0, 1.12, -2.55), linen)
	Figure.add_mesh(self, Figure.box(Vector3(0.05, 2.1, 4.9)), Vector3(-1.7, 1.12, 0), linen)
	Figure.add_mesh(self, Figure.box(Vector3(0.05, 2.1, 4.9)), Vector3(1.7, 1.12, 0), linen)
	Figure.add_mesh(self, Figure.box(Vector3(3.05, 0.05, 4.85)), Vector3(0, 2.28, 0), linen_dim)
	Figure.add_mesh(self, Figure.box(Vector3(3.55, 0.07, 5.45)), Vector3(0, 2.36, 0), skins)
	Figure.add_mesh(self, Figure.box(Vector3(3.25, 0.05, 5.1)), Vector3(0, 2.42, 0), skins_dark)
	Figure.add_mesh(self, Figure.box(Vector3(0.5, 1.95, 0.04)), Vector3(-0.75, 1.05, 2.58), Figure.cloth(Color(0.16, 0.26, 0.5)))
	Figure.add_mesh(self, Figure.box(Vector3(0.22, 1.95, 0.04)), Vector3(-0.38, 1.05, 2.6), Figure.cloth(Color(0.4, 0.16, 0.38)))
	Figure.add_mesh(self, Figure.box(Vector3(0.5, 1.95, 0.04)), Vector3(0.85, 1.05, 2.58), Figure.cloth(Color(0.58, 0.16, 0.14)))
	Figure.add_mesh(self, Figure.box(Vector3(1.1, 0.72, 1.1)), Vector3(0.1, 0.36, 3.7), bronze)
	Figure.add_mesh(self, Figure.box(Vector3(0.86, 0.05, 0.86)), Vector3(0.1, 0.74, 3.7), grate)
	for sx in [-0.48, 0.48]:
		for sz in [-0.48, 0.48]:
			Figure.add_mesh(self, Figure.cylinder(0.0, 0.04, 0.2, 6), Vector3(0.1 + sx, 0.8, 3.7 + sz), bronze, Vector3.ZERO, false)
	Figure.add_mesh(self, Figure.cylinder(0.08, 0.1, 0.42, 8), Vector3(-1.2, 0.26, 3.35), bronze)
	Figure.add_mesh(self, Figure.cylinder(0.32, 0.26, 0.14, 12), Vector3(-1.2, 0.52, 3.35), bronze)
	Figure.add_mesh(self, Figure.cylinder(0.028, 0.038, 0.85, 6), Vector3(0.4, 0.55, 0.2), gold, Vector3.ZERO, false)
	for branch in [-0.32, 0.0, 0.32]:
		Figure.span(self, Vector3(0.4, 0.85, 0.2), Vector3(0.4 + branch, 1.22, 0.2), 0.016, gold)
		Figure.add_mesh(self, Figure.sphere(0.04, 0.06, 8), Vector3(0.4 + branch, 1.28, 0.2), Figure.glow(Color(1.0, 0.8, 0.42), 0.7), Vector3.ZERO, false)

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
