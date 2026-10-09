extends Node3D

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _camp: CampSimulation
var _smoke_frames := 0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_navigation()
	add_child(preload("res://scenes/world/desert_terrain.tscn").instantiate())
	add_child(preload("res://scenes/world/tabernacle_camp.tscn").instantiate())
	var crowd := CrowdLod.new()
	crowd.name = "Crowd"
	add_child(crowd)
	_spawn_leaders()
	_camp = CampSimulation.new()
	_camp.name = "CampSimulation"
	add_child(_camp)
	var missions := MissionManager.new()
	missions.name = "MissionManager"
	add_child(missions)
	var raids := RaidDirector.new()
	raids.name = "RaidDirector"
	add_child(raids)
	var audio := Node.new()
	audio.name = "AudioStings"
	audio.set_script(load("res://systems/audio_stings.gd"))
	add_child(audio)
	var beacon := preload("res://scenes/world/objective_beacon.tscn").instantiate()
	add_child(beacon)
	add_child(preload("res://scenes/ui/hud.tscn").instantiate())
	add_child(preload("res://scenes/ui/split_screen_canvas.tscn").instantiate())
	add_child(preload("res://scenes/ui/touch_controls.tscn").instantiate())


func _process(_delta: float) -> void:
	if _camp:
		_apply_daylight(_camp.hour)
	if OS.get_environment("EXODUS_SMOKE") == "1":
		_smoke_frames += 1
		if _smoke_frames == 45:
			_smoke_quit()


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color(0.3, 0.48, 0.74)
	_sky.sky_horizon_color = Color(0.9, 0.64, 0.38)
	_sky.ground_horizon_color = Color(0.72, 0.52, 0.32)
	_sky.ground_bottom_color = Color(0.4, 0.28, 0.16)
	_sky.sun_angle_max = 26.0
	var sky := Sky.new()
	sky.sky_material = _sky
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.65
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_bloom = 0.12
	_env.glow_hdr_threshold = 1.05
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_density = 0.0032
	_env.fog_light_color = Color(0.84, 0.68, 0.46)
	_env.fog_aerial_perspective = 0.4
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 90.0
	add_child(_sun)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(420, 2, 420)
	shape_node.shape = box
	shape_node.position.y = -1.0
	body.add_child(shape_node)
	add_child(body)


func _build_navigation() -> void:
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.8
	mesh.cell_height = 0.3
	mesh.agent_height = 1.8
	mesh.agent_radius = 0.4
	var span := 200.0
	mesh.vertices = PackedVector3Array([
		Vector3(-span, 0, -span),
		Vector3(span, 0, -span),
		Vector3(span, 0, span),
		Vector3(-span, 0, span),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	add_child(region)


func _spawn_leaders() -> void:
	var root := Node3D.new()
	root.name = "Leaders"
	add_child(root)
	var scenes := {
		&"Moses": "res://scenes/player/moses.tscn",
		&"Aaron": "res://scenes/player/aaron.tscn",
		&"Joshua": "res://scenes/player/joshua.tscn",
		&"Miriam": "res://scenes/player/miriam.tscn",
	}
	for character_name in [&"Moses", &"Aaron", &"Joshua", &"Miriam"]:
		var leader := (load(scenes[character_name]) as PackedScene).instantiate() as Node3D
		leader.position = Sites.SPAWNS[character_name]
		root.add_child(leader)


func _apply_daylight(hour: float) -> void:
	var morning := smoothstep(5.2, 7.6, hour)
	var evening := 1.0 - smoothstep(17.0, 19.3, hour)
	var dayness := clampf(morning * evening, 0.0, 1.0)
	_sun.light_energy = lerpf(0.05, 1.45, dayness)
	_sun.light_color = Color(1.0, lerpf(0.55, 0.93, dayness), lerpf(0.35, 0.78, dayness))
	var arc := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	_sun.rotation_degrees = Vector3(lerpf(-15.0, -155.0, arc), 38.0, 0.0)
	_sun.shadow_enabled = dayness > 0.25 and SessionManager.local_controlled_count() < 3
	_env.ambient_light_energy = lerpf(0.16, 0.7, dayness)
	_sky.sky_top_color = Color(0.3, 0.48, 0.74).lerp(Color(0.02, 0.03, 0.07), 1.0 - dayness)
	_sky.sky_horizon_color = Color(0.9, 0.64, 0.38).lerp(Color(0.12, 0.08, 0.1), 1.0 - dayness)
	_env.fog_light_color = Color(0.84, 0.68, 0.46).lerp(Color(0.08, 0.06, 0.08), 1.0 - dayness)
	var fire_energy := lerpf(1.5, 0.12, dayness)
	for node in get_tree().get_nodes_in_group("campfire_light"):
		if node is Light3D:
			(node as Light3D).light_energy = fire_energy


func _smoke_quit() -> void:
	var leaders := get_tree().get_nodes_in_group("leaders")
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	var manna := get_tree().get_nodes_in_group("manna")
	var grounded := true
	for leader in leaders:
		if leader is Node3D and (leader as Node3D).global_position.y < -1.0:
			grounded = false
	var ok := (
		leaders.size() == 4
		and camp != null
		and camp.murmuring > 0.0
		and missions != null
		and missions.active_mission != null
		and manna.size() > 0
		and grounded
	)
	print("SMOKE ", "OK" if ok else "FAIL", " leaders=", leaders.size(), " manna=", manna.size())
	get_tree().quit(0 if ok else 1)
