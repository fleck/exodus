class_name Amalekite
extends CharacterBody3D

var health: float = 150.0
var max_health: float = 150.0

var _attack_wait: float = 0.6
var _dead := false
var _rig: Dictionary = {}


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
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var variety := int(absf(position.x * 8.0 + position.z * 3.0)) % 4
	var hides: Array[Color] = [
		Color(0.38, 0.16, 0.12),
		Color(0.28, 0.18, 0.12),
		Color(0.44, 0.22, 0.14),
		Color(0.22, 0.13, 0.11),
	]
	var skins: Array[Color] = [
		Color(0.46, 0.3, 0.2),
		Color(0.38, 0.26, 0.18),
		Color(0.52, 0.36, 0.24),
		Color(0.34, 0.22, 0.16),
	]
	_rig = Figure.build(visual, &"amalekite", hides[variety], Color(0.5, 0.34, 0.18), skins[variety], variety)
	if NetworkManager.online():
		set_multiplayer_authority(1)


func _process(_delta: float) -> void:
	if _dead or _rig.is_empty():
		return
	var speed := Vector2(velocity.x, velocity.z).length() / 3.3
	var action := "strike" if _attack_wait > 0.92 else ""
	Figure.pose(_rig, Time.get_ticks_msec() * 0.001, speed, action)


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
			rotation.y = atan2(dir.x, dir.z)
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
