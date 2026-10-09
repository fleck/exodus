class_name MannaPickup
extends CampInteractable

var _taken := false


func _ready() -> void:
	super._ready()
	add_to_group("manna")
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.28
	mesh.mesh = sphere
	mesh.position.y = 0.35
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.94, 0.82)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.95, 0.75)
	material.emission_energy_multiplier = 0.7
	material.roughness = 0.35
	mesh.material_override = material
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.93, 0.7)
	light.light_energy = 0.35
	light.omni_range = 2.4
	light.shadow_enabled = false
	light.position.y = 0.4
	add_child(light)


func _process(delta: float) -> void:
	rotate_y(delta * 0.8)
	position.y = 0.15 + sin(Time.get_ticks_msec() * 0.003 + position.x) * 0.05


func prompt_for(by: Node) -> String:
	if str(by.get("character_name")) == "Miriam":
		return "Gather manna"
	return "Gather manna"


func interact(by: Node) -> bool:
	if NetworkManager.online() and not multiplayer.is_server():
		_rpc_take.rpc_id(1, str(by.get("character_name")))
		return true
	_take(str(by.get("character_name")))
	return true


func _take(who: String) -> void:
	if _taken:
		return
	_taken = true
	var sim := camp()
	if sim:
		var bonus := 3.0 if who == "Miriam" else 2.0
		var amount := maxi(1, int(round(bonus * sim.gather_multiplier())))
		sim.add_manna(amount)
	queue_free()


@rpc("any_peer", "reliable")
func _rpc_take(who: String) -> void:
	if multiplayer.is_server():
		_take(who)
