extends Node3D

var _manna_root: Node3D
var _spawner: MultiplayerSpawner
var _flies: CPUParticles3D
var _flames: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_tents()
	_build_fires()
	_place(Tabernacle.new(), Sites.TABERNACLE)
	_place_site("rock", true, Sites.ROCK)
	_place_site("hill", false, Sites.HILL)
	var spring := BitterSpring.new()
	spring.position = Sites.MARAH
	add_child(spring)
	var calf := GoldenCalf.new()
	calf.position = Sites.CALF
	add_child(calf)
	var trees := [Vector3(-16, 0, 14), Vector3(18, 0, -12), Vector3(-36, 0, -8), Vector3(28, 0, 22), Vector3(8, 0, 36)]
	for i in trees.size():
		var tree := WoodTree.new()
		tree.tree_id = i + 1
		tree.position = trees[i]
		add_child(tree)
	_manna_root = Node3D.new()
	_manna_root.name = "Manna"
	add_child(_manna_root)
	_spawner = MultiplayerSpawner.new()
	add_child(_spawner)
	_spawner.spawn_path = NodePath("../Manna")
	_spawner.spawn_function = _make_manna
	_flies = CPUParticles3D.new()
	_flies.amount = 28
	_flies.lifetime = 1.4
	_flies.explosiveness = 0.8
	_flies.one_shot = true
	_flies.emitting = false
	_flies.position = Vector3(2, 0.6, 2)
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color(0.15, 0.12, 0.08)
	dust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	quad.material = dust
	_flies.mesh = quad
	add_child(_flies)
	EventBus.dawn_reached.connect(_on_dawn)
	EventBus.manna_spoiled.connect(func() -> void: _flies.restart())
	if not NetworkManager.online() or multiplayer.is_server():
		call_deferred("spawn_manna", 12)


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	for i in _flames.size():
		var flick := 0.84 + sin(time * 11.0 + float(i) * 1.7) * 0.16
		_flames[i].scale = Vector3(0.92 + flick * 0.1, flick, 0.92 + flick * 0.1)


func spawn_manna(count: int) -> void:
	for child in _manna_root.get_children():
		child.queue_free()
	for i in count:
		var angle := randf() * TAU
		var dist := randf_range(9.0, 17.0)
		var pos := Vector3(cos(angle) * dist, 0.2, sin(angle) * dist)
		if NetworkManager.online():
			_spawner.spawn(pos)
		else:
			_manna_root.add_child(_make_manna(pos))
	EventBus.manna_spawned.emit(count)


func _on_dawn(_day: int, falls: bool) -> void:
	if NetworkManager.online() and not multiplayer.is_server():
		return
	if falls:
		spawn_manna(12)
	else:
		for child in _manna_root.get_children():
			child.queue_free()


func _make_manna(data: Variant) -> Node:
	var flake := MannaPickup.new()
	flake.position = data
	return flake


func _place(node: Node3D, at: Vector3) -> void:
	node.position = at
	add_child(node)


func _place_site(site_id: String, water: bool, at: Vector3) -> void:
	var site := MiracleSite.new()
	site.site_id = site_id
	site.grants_water = water
	site.position = at
	add_child(site)


func _build_tents() -> void:
	var cloths: Array[Color] = [
		Color(0.16, 0.12, 0.1),
		Color(0.4, 0.26, 0.16),
		Color(0.28, 0.2, 0.14),
		Color(0.48, 0.34, 0.22),
		Color(0.22, 0.16, 0.12),
	]
	for i in 8:
		var angle := float(i) / 8.0 * TAU
		var root := Node3D.new()
		root.position = Vector3(cos(angle) * 13.0, 0, sin(angle) * 13.0)
		root.rotation.y = atan2(-root.position.x, -root.position.z)
		add_child(root)
		_tent(root, cloths[i % cloths.size()], i)


func _tent(root: Node3D, color: Color, index: int) -> void:
	var hide := Figure.cloth(color, 0.93)
	var stripe := Figure.cloth(color.darkened(0.22), 0.9)
	var shade := Figure.cloth(color.darkened(0.45), 0.95)
	var pole := Figure.wood(Color(0.4, 0.28, 0.16))
	var rope := Figure.cloth(Color(0.55, 0.46, 0.32), 0.8)
	# A-frame goat-hair tent. Panels lean in and meet along the ridge.
	Figure.add_mesh(root, Figure.box(Vector3(0.045, 2.5, 3.5)), Vector3(-0.82, 0.9, 0), hide, Vector3(0, 0, -43))
	Figure.add_mesh(root, Figure.box(Vector3(0.045, 2.5, 3.5)), Vector3(0.82, 0.9, 0), hide if index % 2 == 0 else stripe, Vector3(0, 0, 43))
	Figure.add_mesh(root, Figure.cylinder(0.05, 0.05, 3.5, 6), Vector3(0, 1.78, 0), pole, Vector3(90, 0, 0), false)
	Figure.add_mesh(root, Figure.cylinder(0.04, 0.045, 1.7, 6), Vector3(0, 0.85, 1.45), pole, Vector3.ZERO, false)
	Figure.add_mesh(root, Figure.cylinder(0.04, 0.045, 1.7, 6), Vector3(0, 0.85, -1.45), pole, Vector3.ZERO, false)
	Figure.add_mesh(root, Figure.box(Vector3(2.0, 1.25, 0.04)), Vector3(0, 0.65, -1.7), shade)
	Figure.add_mesh(root, Figure.box(Vector3(0.7, 1.35, 0.03)), Vector3(-0.85, 0.7, 1.68), stripe)
	Figure.add_mesh(root, Figure.cylinder(1.55, 1.55, 0.03, 12), Vector3(0, 0.02, 0), Figure.cloth(color.darkened(0.35), 1.0), Vector3.ZERO, false)
	Figure.span(root, Vector3(0, 1.7, 1.5), Vector3(1.9, 0.02, 1.7), 0.012, rope)
	Figure.span(root, Vector3(0, 1.7, -1.5), Vector3(-1.85, 0.02, -1.7), 0.012, rope)
	Figure.add_mesh(root, Figure.cylinder(0.02, 0.025, 0.16, 5), Vector3(1.9, 0.08, 1.7), pole, Vector3(20, 0, 0), false)
	Figure.add_mesh(root, Figure.cylinder(0.02, 0.025, 0.16, 5), Vector3(-1.85, 0.08, -1.7), pole, Vector3(20, 0, 0), false)


func _build_fires() -> void:
	var spots: Array[Vector3] = [Vector3(-6, 0, 3), Vector3(7, 0, 2), Vector3(1, 0, 9)]
	var bark := Figure.wood(Color(0.28, 0.16, 0.08))
	var ash := Figure.stone(Color(0.28, 0.24, 0.2))
	for spot in spots:
		var fire := Node3D.new()
		fire.position = spot
		for i in 6:
			var angle := float(i) / 6.0 * TAU
			var rock := Figure.add_mesh(fire, Figure.sphere(0.14, 0.18, 8), Vector3(cos(angle) * 0.42, 0.06, sin(angle) * 0.42), ash, Vector3.ZERO, false)
			rock.scale = Vector3(1.1, 0.55, 0.9)
		Figure.add_mesh(fire, Figure.cylinder(0.06, 0.07, 0.7, 6), Vector3(0, 0.1, 0), bark, Vector3(0, 30, 78), false)
		Figure.add_mesh(fire, Figure.cylinder(0.05, 0.06, 0.62, 6), Vector3(0, 0.12, 0), bark, Vector3(80, 10, 20), false)
		Figure.add_mesh(fire, Figure.cylinder(0.045, 0.055, 0.55, 6), Vector3(0.05, 0.14, 0.02), bark, Vector3(70, 80, 0), false)
		var outer := Figure.add_mesh(fire, Figure.cylinder(0.0, 0.16, 0.48, 8), Vector3(0, 0.42, 0), _flame_mat(Color(1.0, 0.38, 0.08, 0.85), 1.6), Vector3.ZERO, false)
		Figure.add_mesh(outer, Figure.cylinder(0.0, 0.08, 0.32, 8), Vector3(0, 0.08, 0), _flame_mat(Color(1.0, 0.82, 0.35, 0.95), 2.2), Vector3.ZERO, false)
		_flames.append(outer)
		var sparks := CPUParticles3D.new()
		sparks.amount = 8
		sparks.lifetime = 0.7
		sparks.direction = Vector3.UP
		sparks.spread = 16.0
		sparks.gravity = Vector3(0, 0.15, 0)
		sparks.initial_velocity_min = 0.35
		sparks.initial_velocity_max = 0.9
		sparks.scale_amount_min = 0.02
		sparks.scale_amount_max = 0.05
		var ember := StandardMaterial3D.new()
		ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ember.albedo_color = Color(1.0, 0.55, 0.15)
		ember.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var mote := QuadMesh.new()
		mote.size = Vector2(0.05, 0.05)
		mote.material = ember
		sparks.mesh = mote
		sparks.position.y = 0.35
		fire.add_child(sparks)
		var lamp := AreaLight3D.new()
		lamp.area_size = Vector2(0.8, 0.8)
		lamp.area_range = 6.0
		lamp.light_color = Color(1.0, 0.62, 0.28)
		lamp.light_energy = 0.2
		lamp.light_size = 0.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(0, 1.4, 0)
		lamp.rotation_degrees = Vector3(-90, 0, 0)
		lamp.add_to_group("campfire_light")
		fire.add_child(lamp)
		add_child(fire)


func _flame_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
