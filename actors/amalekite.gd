class_name Amalekite
extends CharacterBody3D

var health: float = 150.0
var max_health: float = 150.0

var _attack_wait: float = 0.6
var _dead := false


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 7
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.7
	shape_node.shape = capsule
	shape_node.position.y = 0.85
	add_child(shape_node)
	var mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.38
	body.height = 1.5
	mesh.mesh = body
	mesh.position.y = 0.95
	var hide := StandardMaterial3D.new()
	hide.albedo_color = Color(0.32, 0.14, 0.1)
	hide.roughness = 0.8
	mesh.material_override = hide
	add_child(mesh)
	var helm := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.28
	helm.mesh = sphere
	helm.position.y = 1.7
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.5, 0.42)
	metal.metallic = 0.7
	metal.roughness = 0.35
	helm.material_override = metal
	add_child(helm)
	if NetworkManager.online():
		set_multiplayer_authority(1)


func _physics_process(delta: float) -> void:
	if _dead or not NetworkManager.has_authority(self):
		return
	var target := _nearest_leader()
	if target == null:
		return
	if global_position.distance_to(Sites.CAMP) < 7.5:
		_breach()
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() < 1.45:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		_attack_wait -= delta
		if _attack_wait <= 0.0:
			_attack_wait = 1.15
			target.receive_hit(global_position, 12.0)
	else:
		var dir := to.normalized()
		velocity.x = dir.x * 3.3
		velocity.z = dir.z * 3.3
		if dir.length_squared() > 0.01:
			look_at(global_position + dir, Vector3.UP)
	if not is_on_floor():
		velocity.y -= 28.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()


func apply_damage(amount: float) -> void:
	if NetworkManager.online() and not multiplayer.is_server():
		_rpc_damage.rpc_id(1, amount)
		return
	if _dead:
		return
	health -= amount
	if health <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	var raids := get_tree().get_first_node_in_group("raids")
	if raids:
		raids.call("notify_removed")
	queue_free()


func _breach() -> void:
	if _dead:
		return
	_dead = true
	var sim := get_tree().get_first_node_in_group("camp") as CampSimulation
	if sim:
		sim.add_murmuring(8.0 * sim.pressure(), "Raiders reached the tents.")
	var raids := get_tree().get_first_node_in_group("raids")
	if raids:
		raids.call("notify_removed")
	queue_free()


func _nearest_leader() -> CoopController:
	var best: CoopController = null
	var best_dist := 80.0
	for node in get_tree().get_nodes_in_group("leaders"):
		var leader := node as CoopController
		if leader == null:
			continue
		var dist := global_position.distance_to(leader.global_position)
		if dist < best_dist:
			best_dist = dist
			best = leader
	return best


@rpc("any_peer", "reliable")
func _rpc_damage(amount: float) -> void:
	if multiplayer.is_server():
		apply_damage(amount)
