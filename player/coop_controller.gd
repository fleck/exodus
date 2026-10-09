# player/coop_controller.gd
class_name CoopController
extends CharacterBody3D
## Possession, companion steering, and network authority for one leader.
## Human input and AI duties share this body so solo swap and co-op
## run the same campaign.

const GRAVITY := 28.0
const CAMERA_YAW := -0.84
const WORLD_RADIUS := 175.0

@export var character_name: StringName = &"Moses"
@export var move_speed: float = 5.0
@export var robe_color: Color = Color(0.93, 0.9, 0.82)
@export var trim_color: Color = Color(0.55, 0.4, 0.22)
@export var skin_color: Color = Color(0.58, 0.4, 0.28)
@export var prop_kind: String = "staff"
@export var body_scale: float = 1.0

var is_possessed_by_local_human: bool = false
var controlled_by_peer: int = 0
var leader_target: Node3D = null
var stamina: float = 100.0
var stamina_max: float = 100.0
var is_channeling: bool = false
var is_bracing: bool = false
var is_performing_ritual: bool = false
var sprinting: bool = false
var heal_pulse: float = 0.0
var stagger_timer: float = 0.0

var just_interact: bool = false
var just_ability: bool = false
var just_attack: bool = false
var hold_ability: bool = false

var camera_pivot: Node3D
var camera: Camera3D
var listener: AudioListener3D
var nav_agent: NavigationAgent3D
var input_router: InputRouter
var _visual: Node3D
var _ring: MeshInstance3D
var _bt: AIBehaviorTree
var _attack_cd: float = 0.0
var _edge_note: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 7
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	_configure_rig()
	_build_visual()
	_build_sync()
	_build_behavior()
	SessionManager.register_leader(self)


func _exit_tree() -> void:
	SessionManager.unregister_leader(self)


func _physics_process(delta: float) -> void:
	if not NetworkManager.has_authority(self):
		_align_camera()
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	sprinting = false
	if is_possessed_by_local_human:
		_read_inputs()
	else:
		_clear_inputs()
	_regen_stamina(delta)
	if stagger_timer > 0.0:
		stagger_timer -= delta
		_halt(delta)
		_finish_frame()
		return
	_process_role(delta)
	if _locks_feet():
		_halt(delta)
	elif is_possessed_by_local_human:
		_process_human_movement(delta)
	else:
		_process_ai_companion(delta)
	_finish_frame()


func assign_control(peer: int, device: int, scheme: int) -> void:
	controlled_by_peer = peer
	var me := NetworkManager.local_peer_id()
	is_possessed_by_local_human = peer == me and peer != 0
	var authority := peer if peer > 0 else 1
	if NetworkManager.online():
		set_multiplayer_authority(authority)
	input_router.device_id = device if is_possessed_by_local_human else -1
	input_router.keyboard_scheme = scheme if is_possessed_by_local_human else 0
	input_router.network_peer_id = authority
	if _ring:
		_ring.visible = is_possessed_by_local_human


func refresh_camera(split: bool, use_listener: bool) -> void:
	if camera:
		camera.current = is_possessed_by_local_human and not split
	if listener:
		listener.current = use_listener


func ability_hint() -> String:
	return "Ability"


func control_hint() -> String:
	if input_router.device_id >= 0:
		return "Stick move · A interact · RB ability · X attack"
	if input_router.keyboard_scheme == 1:
		return "IJKL move · U interact · O ability · P attack"
	var swap := ""
	if SessionManager.local_controlled_count() <= 1:
		swap = " · 1-4 swap"
	return "WASD move · E interact · R ability · F attack" + swap


func status_line() -> String:
	if stagger_timer > 0.2:
		return "Staggered"
	if is_channeling:
		return "Channeling"
	if is_bracing:
		return "Bracing Moses"
	if is_performing_ritual:
		return "Offering incense"
	if sprinting:
		return "Sprinting"
	if heal_pulse > 0.2:
		return "Song carrying"
	return "Ready"


func current_prompt() -> String:
	if not is_possessed_by_local_human:
		return ""
	var target := _nearest_in_group("interactable", 2.8)
	if target == null:
		return ""
	return String(target.call("prompt_for", self))


func receive_hit(from_pos: Vector3, amount: float) -> void:
	if get_multiplayer_authority() != NetworkManager.local_peer_id():
		if NetworkManager.online() and multiplayer.is_server():
			_rpc_receive_hit.rpc_id(get_multiplayer_authority(), from_pos, amount)
		return
	_apply_hit(from_pos, amount)


func attack_damage() -> float:
	return 14.0


func attack_range() -> float:
	return 1.9


func attack_cooldown() -> float:
	return 0.55


func _process_role(_delta: float) -> void:
	if not is_possessed_by_local_human:
		return
	if just_interact:
		_try_interact()
	if just_attack:
		_perform_attack()


func _ai_duty(_delta: float) -> bool:
	return false


func _locks_feet() -> bool:
	return is_channeling or is_performing_ritual or is_bracing


func set_ritual_cooldown(_seconds: float) -> void:
	pass


func _read_inputs() -> void:
	just_interact = input_router.is_action_just_pressed(&"interact")
	just_ability = input_router.is_action_just_pressed(&"channel_miracle")
	just_attack = input_router.is_action_just_pressed(&"attack")
	hold_ability = input_router.is_action_pressed(&"channel_miracle")


func _clear_inputs() -> void:
	just_interact = false
	just_ability = false
	just_attack = false
	hold_ability = false


func _regen_stamina(delta: float) -> void:
	if is_channeling or sprinting:
		return
	stamina = minf(stamina_max, stamina + 14.0 * delta)


func _process_human_movement(delta: float) -> void:
	var input_dir := input_router.get_movement_vector()
	var theta := CAMERA_YAW
	# Node3D yaw: local +X is right, local -Z is where the camera looks.
	var right := Vector3(cos(theta), 0.0, -sin(theta))
	var forward := Vector3(-sin(theta), 0.0, -cos(theta))
	var direction := right * input_dir.x + forward * (-input_dir.y)
	direction.y = 0.0
	var speed := move_speed * (1.45 if sprinting else 1.0)
	if direction.length_squared() > 0.001:
		_slide_with(delta, direction.normalized() * speed)
	else:
		var brake := move_speed * 6.0 * delta
		var planar := Vector3(
			move_toward(velocity.x, 0.0, brake),
			0.0,
			move_toward(velocity.z, 0.0, brake)
		)
		_slide_with(delta, planar)


func _process_ai_companion(delta: float) -> void:
	if _bt:
		_bt.tick(self, delta)
	else:
		_bt_follow(self, delta)


func _bt_duty(actor: Node, delta: float) -> bool:
	return (actor as CoopController)._ai_duty(delta)


func _bt_follow(actor: Node, delta: float) -> bool:
	var body := actor as CoopController
	if body.leader_target == null:
		body._halt(delta)
		return true
	var dest := body._follow_point()
	if body.global_position.distance_to(dest) < 1.8:
		body._halt(delta)
		return true
	body._steer_to(dest, delta, body.move_speed * 0.92)
	return true


func _follow_point() -> Vector3:
	var slot := 0
	match character_name:
		&"Aaron":
			slot = 1
		&"Joshua":
			slot = 2
		&"Miriam":
			slot = 3
	var angle := float(slot) * TAU / 4.0
	return leader_target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 2.7


func _steer_to(world_pos: Vector3, delta: float, speed: float) -> void:
	var dest := world_pos
	if nav_agent:
		nav_agent.target_position = world_pos
		var path := nav_agent.get_current_navigation_path()
		if path.size() >= 2:
			dest = nav_agent.get_next_path_position()
	var flat := Vector3(dest.x, global_position.y, dest.z)
	var offset := flat - global_position
	offset.y = 0.0
	if offset.length() < 0.75:
		_slide_with(delta, Vector3.ZERO)
		return
	var desired := offset.normalized() * speed
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired)
	else:
		_slide_with(delta, desired)


func _halt(delta: float) -> void:
	var brake := move_speed * 8.0 * delta
	var planar := Vector3(
		move_toward(velocity.x, 0.0, brake),
		0.0,
		move_toward(velocity.z, 0.0, brake)
	)
	_slide_with(delta, planar)


func _slide_with(delta: float, planar: Vector3) -> void:
	velocity.x = planar.x
	velocity.z = planar.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	var facing := Vector3(planar.x, 0.0, planar.z)
	if facing.length_squared() > 0.2:
		_face_direction(facing, 1.0 - exp(-12.0 * delta))


func _on_safe_velocity_computed(safe_velocity: Vector3) -> void:
	if is_possessed_by_local_human or not NetworkManager.has_authority(self):
		return
	_slide_with(get_physics_process_delta_time(), Vector3(safe_velocity.x, 0.0, safe_velocity.z))


func _face_direction(dir: Vector3, weight: float) -> void:
	# Local +Z is the front (breastplate and props).
	var yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, weight)


func _finish_frame() -> void:
	_clamp_world()
	_align_camera()
	_tick_visual()


func _clamp_world() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() <= WORLD_RADIUS:
		_edge_note = false
		return
	var back := flat.normalized() * (WORLD_RADIUS - 1.0)
	global_position.x = back.x
	global_position.z = back.y
	velocity.x = 0.0
	velocity.z = 0.0
	if not _edge_note:
		_edge_note = true
		EventBus.notification.emit("The way further into the desert is shut.")


func _align_camera() -> void:
	if camera_pivot == null:
		return
	camera_pivot.rotation.y = CAMERA_YAW - rotation.y


func _tick_visual() -> void:
	if _visual == null:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	var bob := absf(sin(Time.get_ticks_msec() * 0.012)) * (0.05 if moving else 0.012)
	_visual.position.y = bob


func _try_interact() -> bool:
	var target := _nearest_in_group("interactable", 2.8)
	if target == null:
		return false
	if not bool(target.call("can_use", self)):
		var why := String(target.call("prompt_for", self))
		if why != "":
			EventBus.notification.emit(why)
		return false
	return bool(target.call("interact", self))


func _perform_attack() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown()
	var reach := attack_range()
	var foe := _nearest_in_group("enemies", reach)
	var calf := _nearest_in_group("calf", reach + 0.5)
	var victim: Node3D = null
	if foe != null and calf != null:
		var foe_dist := global_position.distance_to(foe.global_position)
		var calf_dist := global_position.distance_to(calf.global_position)
		victim = foe if foe_dist <= calf_dist else calf
	elif foe != null:
		victim = foe
	else:
		victim = calf
	if victim == null:
		return
	var away := victim.global_position - global_position
	away.y = 0.0
	if away.length_squared() > 0.01:
		_face_direction(away.normalized(), 1.0)
	if victim.is_in_group("calf"):
		victim.call("strike", attack_damage())
	else:
		victim.call("apply_damage", attack_damage())


func _apply_hit(from_pos: Vector3, amount: float) -> void:
	stagger_timer = 0.38
	stamina = maxf(0.0, stamina - amount)
	var away := global_position - from_pos
	away.y = 0.0
	if away.length_squared() > 0.01:
		velocity += away.normalized() * 5.5
	is_channeling = false


func _nearest_in_group(group_name: String, max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_dist := max_dist
	for node in get_tree().get_nodes_in_group(group_name):
		if not node is Node3D:
			continue
		var body := node as Node3D
		var dist := global_position.distance_to(body.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = body
	return best


func _configure_rig() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		add_child(shape_node)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	shape_node.shape = capsule
	shape_node.position = Vector3(0, 0.85, 0)

	camera_pivot = get_node_or_null("CameraPivot") as Node3D
	if camera_pivot == null:
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		add_child(camera_pivot)
	camera = camera_pivot.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera_pivot.add_child(camera)
	camera.position = Vector3(0, 2.35, 6.1)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	camera.fov = 68.0
	camera.current = false
	var attrs := CameraAttributesPractical.new()
	attrs.exposure_sensitivity = 90.0
	attrs.auto_exposure_enabled = false
	camera.attributes = attrs

	listener = camera_pivot.get_node_or_null("AudioListener3D") as AudioListener3D
	if listener == null:
		listener = AudioListener3D.new()
		listener.name = "AudioListener3D"
		camera_pivot.add_child(listener)

	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent == null:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		add_child(nav_agent)
	nav_agent.path_desired_distance = 0.7
	nav_agent.target_desired_distance = 1.5
	nav_agent.avoidance_enabled = false
	nav_agent.radius = 0.42
	nav_agent.height = 1.7
	nav_agent.max_speed = move_speed
	if not nav_agent.velocity_computed.is_connected(_on_safe_velocity_computed):
		nav_agent.velocity_computed.connect(_on_safe_velocity_computed)

	input_router = get_node_or_null("InputRouter") as InputRouter
	if input_router == null:
		input_router = InputRouter.new()
		input_router.name = "InputRouter"
		add_child(input_router)


func _build_visual() -> void:
	_visual = get_node_or_null("Visual") as Node3D
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "Visual"
		add_child(_visual)
	_visual.scale = Vector3.ONE * body_scale

	var robe := MeshInstance3D.new()
	var robe_mesh := CapsuleMesh.new()
	robe_mesh.radius = 0.38
	robe_mesh.height = 1.15
	robe.mesh = robe_mesh
	robe.position = Vector3(0, 0.95, 0)
	robe.material_override = _cloth(robe_color)
	_visual.add_child(robe)

	var hem := MeshInstance3D.new()
	var hem_mesh := CylinderMesh.new()
	hem_mesh.top_radius = 0.42
	hem_mesh.bottom_radius = 0.62
	hem_mesh.height = 0.55
	hem.mesh = hem_mesh
	hem.position = Vector3(0, 0.48, 0)
	hem.material_override = _cloth(robe_color.darkened(0.08))
	_visual.add_child(hem)

	var trim := MeshInstance3D.new()
	var trim_mesh := CylinderMesh.new()
	trim_mesh.top_radius = 0.4
	trim_mesh.bottom_radius = 0.4
	trim_mesh.height = 0.08
	trim.mesh = trim_mesh
	trim.position = Vector3(0, 1.22, 0)
	trim.material_override = _cloth(trim_color, 0.45, 0.35)
	_visual.add_child(trim)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	head.mesh = head_mesh
	head.position = Vector3(0, 1.68, 0)
	head.material_override = _cloth(skin_color, 0.72, 0.0)
	_visual.add_child(head)

	_add_prop()

	var label := Label3D.new()
	label.text = String(character_name)
	label.font_size = 42
	label.position = Vector3(0, 2.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.98, 0.94, 0.84)
	label.outline_size = 8
	label.outline_modulate = Color(0.1, 0.07, 0.04)
	label.no_depth_test = true
	_visual.add_child(label)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.58
	_ring.mesh = torus
	_ring.position = Vector3(0, 0.06, 0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = trim_color
	ring_mat.emission_enabled = true
	ring_mat.emission = trim_color
	ring_mat.emission_energy_multiplier = 0.6
	_ring.material_override = ring_mat
	_ring.visible = false
	add_child(_ring)


func _add_prop() -> void:
	match prop_kind:
		"staff":
			var staff := MeshInstance3D.new()
			var stick := CylinderMesh.new()
			stick.top_radius = 0.035
			stick.bottom_radius = 0.045
			stick.height = 2.15
			staff.mesh = stick
			staff.position = Vector3(0.42, 1.05, 0.05)
			staff.rotation_degrees = Vector3(0, 0, -8)
			staff.material_override = _cloth(Color(0.42, 0.28, 0.16), 0.8, 0.0)
			_visual.add_child(staff)
		"breastplate":
			var plate := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.42, 0.38, 0.12)
			plate.mesh = box
			plate.position = Vector3(0, 1.15, 0.22)
			plate.material_override = _cloth(trim_color, 0.28, 0.85)
			_visual.add_child(plate)
		"spear":
			var shaft := MeshInstance3D.new()
			var stick := CylinderMesh.new()
			stick.top_radius = 0.03
			stick.bottom_radius = 0.03
			stick.height = 2.0
			shaft.mesh = stick
			shaft.position = Vector3(0.38, 1.1, 0)
			shaft.material_override = _cloth(Color(0.36, 0.24, 0.14))
			_visual.add_child(shaft)
			var tip := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.07
			cone.height = 0.28
			tip.mesh = cone
			tip.position = Vector3(0.38, 2.15, 0)
			tip.material_override = _cloth(Color(0.75, 0.72, 0.66), 0.25, 0.9)
			_visual.add_child(tip)
		"timbrel":
			var drum := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.1
			torus.outer_radius = 0.2
			drum.mesh = torus
			drum.position = Vector3(0.32, 1.15, 0.2)
			drum.rotation_degrees = Vector3(70, 20, 0)
			drum.material_override = _cloth(trim_color, 0.4, 0.2)
			_visual.add_child(drum)


func _cloth(color: Color, rough: float = 0.88, metal: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	return material


func _build_sync() -> void:
	if not NetworkManager.online():
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "StateSync"
	var config := SceneReplicationConfig.new()
	for property in ["..:position", "..:rotation", "..:is_channeling", "..:is_bracing", "..:is_performing_ritual", "..:heal_pulse"]:
		var path := NodePath(property)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	sync.replication_interval = 0.05
	add_child(sync)


func _build_behavior() -> void:
	_bt = AIBehaviorTree.new()
	var selector := AIBehaviorTree.Selector.new()
	selector.children = [
		AIBehaviorTree.Leaf.new(_bt_duty),
		AIBehaviorTree.Leaf.new(_bt_follow),
	]
	_bt.root = selector


@rpc("any_peer", "reliable")
func _rpc_receive_hit(from_pos: Vector3, amount: float) -> void:
	_apply_hit(from_pos, amount)
