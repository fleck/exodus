class_name RaidDirector
extends Node

var _raid_day := 0
var _wave := false
var _root: Node3D
var _spawner: MultiplayerSpawner


func _ready() -> void:
	add_to_group("raids")
	_root = Node3D.new()
	_root.name = "Enemies"
	add_child(_root)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "EnemySpawner"
	add_child(_spawner)
	_spawner.spawn_path = NodePath("../Enemies")
	_spawner.spawn_function = _make_enemy


func _process(_delta: float) -> void:
	if NetworkManager.online() and not multiplayer.is_server():
		return
	var sim := get_tree().get_first_node_in_group("camp") as CampSimulation
	if sim == null or sim.game_over:
		return
	if sim.day == _raid_day or sim.hour < 18.0:
		return
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	if missions and missions.active_mission and missions.active_mission.synergy:
		return
	_raid_day = sim.day
	spawn_wave(1 + SessionManager.pressure_peers(), Sites.RAID_SPAWN)


func spawn_battle() -> void:
	spawn_wave(2 + SessionManager.pressure_peers(), Sites.VALLEY + Vector3(8, 0, 6))


func spawn_wave(count: int, origin: Vector3) -> void:
	if NetworkManager.online() and not multiplayer.is_server():
		return
	_wave = true
	for i in count:
		var pos := origin + Vector3(randf_range(-3.5, 3.5), 0.25, randf_range(-3.5, 3.5))
		if NetworkManager.online():
			_spawner.spawn(pos)
		else:
			_root.add_child(_make_enemy(pos))
	EventBus.raid_started.emit(count)
	var sim := get_tree().get_first_node_in_group("camp") as CampSimulation
	if sim:
		sim.announce("Amalekites are on the sand.")


func notify_removed() -> void:
	call_deferred("_check_clear")


func _check_clear() -> void:
	if not _wave:
		return
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return
	_wave = false
	var sim := get_tree().get_first_node_in_group("camp") as CampSimulation
	if sim and not sim.game_over:
		sim.add_murmuring(-6.0, "The raid was turned back.")
	EventBus.enemy_defeated.emit(0)


func _make_enemy(data: Variant) -> Node:
	var enemy := Amalekite.new()
	enemy.position = data
	return enemy
