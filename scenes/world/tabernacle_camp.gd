extends Node3D

var _manna_root: Node3D
var _spawner: MultiplayerSpawner
var _flies: CPUParticles3D


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
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.62, 0.42, 0.28)
	cloth.roughness = 0.9
	for i in 8:
		var angle := float(i) / 8.0 * TAU
		var tent := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.15
		cone.bottom_radius = 1.5
		cone.height = 2.1
		tent.mesh = cone
		tent.material_override = cloth
		tent.position = Vector3(cos(angle) * 11.0, 1.05, sin(angle) * 11.0)
		add_child(tent)


func _build_fires() -> void:
	var spots: Array[Vector3] = [Vector3(-6, 0, 3), Vector3(7, 0, 2), Vector3(1, 0, 9)]
	for spot in spots:
		var fire := Node3D.new()
		fire.position = spot
		var logs := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.18, 0.25)
		logs.mesh = box
		logs.position.y = 0.1
		var bark := StandardMaterial3D.new()
		bark.albedo_color = Color(0.28, 0.16, 0.08)
		logs.material_override = bark
		fire.add_child(logs)
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18
		cone.height = 0.45
		flame.mesh = cone
		flame.position.y = 0.35
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.45, 0.12)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.4, 0.05)
		glow.emission_energy_multiplier = 2.0
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.material_override = glow
		fire.add_child(flame)
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
