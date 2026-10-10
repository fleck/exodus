class_name MannaPickup
extends CampInteractable

var _taken := false


func _ready() -> void:
	super._ready()
	add_to_group("manna")
	var pile := Node3D.new()
	pile.name = "Flakes"
	add_child(pile)
	var wafer := Figure.glow(Color(0.97, 0.94, 0.82), 0.4, 0.4)
	var honey := Figure.glow(Color(0.9, 0.74, 0.38), 0.22, 0.32)
	var spots: Array[Vector3] = [
		Vector3(0, 0.03, 0),
		Vector3(0.09, 0.045, 0.03),
		Vector3(-0.07, 0.04, 0.05),
		Vector3(0.02, 0.055, -0.08),
		Vector3(-0.04, 0.065, -0.02),
		Vector3(0.06, 0.03, -0.04),
	]
	for i in spots.size():
		var radius := 0.085 if i == 0 else 0.045 + float(i) * 0.006
		Figure.add_mesh(pile, Figure.cylinder(radius, radius * 0.92, 0.02, 10), spots[i], wafer if i % 2 == 0 else honey, Vector3(0, float(i) * 22.0, 0), false)
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
