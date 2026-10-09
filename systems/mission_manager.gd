class_name MissionManager
extends Node

const SYNERGY_SECONDS := 16.0

var missions: Array[MissionResource] = []
var index: int = 0
var active_mission: MissionResource = null
var step_index: int = 0
var gather_baseline: int = 0
var synergy_progress: float = 0.0
var _rephidim_spawned := false


func _ready() -> void:
	add_to_group("missions")
	_load()
	EventBus.objective_event.connect(_on_objective)
	EventBus.resource_updated.connect(_on_resource)
	if _authority():
		call_deferred("start_active")


func _process(delta: float) -> void:
	if not _authority() or active_mission == null:
		return
	if active_mission.synergy:
		_tick_synergy(delta)
	else:
		_tick_reach()


func start_active() -> void:
	if not _authority():
		return
	if index >= missions.size():
		active_mission = null
		EventBus.victory.emit("The camp holds together. The wilderness is still ahead.")
		EventBus.notification.emit("The camp holds together. Keep them fed, watered, and quiet.")
		return
	active_mission = missions[index]
	step_index = 0
	synergy_progress = 0.0
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	gather_baseline = 0 if camp == null else camp.manna_gathered_total
	EventBus.mission_started.emit(active_mission)
	EventBus.notification.emit("%s — %s" % [active_mission.title, active_mission.description])
	if active_mission.synergy and not _rephidim_spawned:
		_rephidim_spawned = true
		var raids := get_tree().get_first_node_in_group("raids")
		if raids:
			raids.call("spawn_battle")


func pack_state() -> Dictionary:
	var id := String(active_mission.mission_id) if active_mission else ""
	return {
		"index": index,
		"step": step_index,
		"synergy": synergy_progress,
		"baseline": gather_baseline,
		"active": id,
	}


func apply_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	index = int(data.get("index", index))
	step_index = int(data.get("step", step_index))
	synergy_progress = float(data.get("synergy", synergy_progress))
	gather_baseline = int(data.get("baseline", gather_baseline))
	var id := String(data.get("active", ""))
	if id == "":
		active_mission = null
		return
	if active_mission and String(active_mission.mission_id) == id:
		return
	for mission in missions:
		if String(mission.mission_id) == id:
			active_mission = mission
			EventBus.mission_started.emit(mission)
			return


func step_text() -> String:
	if active_mission == null:
		return "The camp holds. Keep them fed and quiet."
	if active_mission.synergy:
		return "Rephidim  ·  hold every duty   %d%%" % int(round(100.0 * synergy_progress / SYNERGY_SECONDS))
	if step_index >= active_mission.step_ids.size():
		return active_mission.title
	return "%s  ·  %s" % [active_mission.title, _step_label(String(active_mission.step_ids[step_index]))]


func synergy_flags() -> Dictionary:
	var moses := SessionManager.leader(&"Moses") as CoopController
	var aaron := SessionManager.leader(&"Aaron") as CoopController
	var joshua := SessionManager.leader(&"Joshua") as CoopController
	var miriam := SessionManager.leader(&"Miriam") as CoopController
	var fighting := false
	if joshua:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node3D and joshua.global_position.distance_to((enemy as Node3D).global_position) < 14.0:
				fighting = true
				break
		if not fighting and get_tree().get_nodes_in_group("enemies").is_empty() and synergy_progress > 3.0:
			if joshua.global_position.distance_to(Sites.VALLEY) < 16.0:
				fighting = true
	return {
		"moses": moses != null and moses.is_channeling and moses.global_position.distance_to(Sites.HILL) < 9.0,
		"aaron": aaron != null and aaron.is_bracing and moses != null and aaron.global_position.distance_to(moses.global_position) < 3.6,
		"joshua": fighting,
		"miriam": miriam != null and miriam.heal_pulse > 0.15 and miriam.global_position.distance_to(Sites.VALLEY) < 18.0,
	}


func _load() -> void:
	var paths := [
		"res://resources/missions/dawn_harvest.tres",
		"res://resources/missions/waters_of_marah.tres",
		"res://resources/missions/battle_of_rephidim.tres",
		"res://resources/missions/consecrate_tabernacle.tres",
	]
	for path in paths:
		var mission := load(path) as MissionResource
		if mission:
			missions.append(mission)
		else:
			push_error("Failed to load mission %s" % path)
	missions.sort_custom(func(a: MissionResource, b: MissionResource) -> bool:
		return a.sort_order < b.sort_order
	)


func _tick_reach() -> void:
	if active_mission == null or step_index >= active_mission.step_ids.size():
		return
	if StringName(active_mission.step_ids[step_index]) != &"reach_site":
		return
	var mark := active_mission.objective_coordinates
	for leader in get_tree().get_nodes_in_group("leaders"):
		if leader is Node3D and (leader as Node3D).global_position.distance_to(mark) <= 8.0:
			_complete_step()
			return


func _on_objective(step_id: StringName) -> void:
	if not _authority() or active_mission == null or active_mission.synergy:
		return
	if step_index >= active_mission.step_ids.size():
		return
	if StringName(active_mission.step_ids[step_index]) == step_id:
		_complete_step()


func _on_resource(type: StringName, _amount: int) -> void:
	if not _authority() or active_mission == null or type != &"manna":
		return
	if step_index >= active_mission.step_ids.size():
		return
	if StringName(active_mission.step_ids[step_index]) != &"gather_manna":
		return
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	if camp and camp.manna_gathered_total - gather_baseline >= active_mission.goal_amount:
		_complete_step()


func _tick_synergy(delta: float) -> void:
	var flags := synergy_flags()
	var ready: bool = bool(flags["moses"]) and bool(flags["aaron"]) and bool(flags["joshua"]) and bool(flags["miriam"])
	if ready:
		synergy_progress += delta
		if synergy_progress >= SYNERGY_SECONDS:
			synergy_progress = SYNERGY_SECONDS
			_finish()
	else:
		synergy_progress = maxf(0.0, synergy_progress - delta * 0.35)


func _complete_step() -> void:
	if active_mission == null:
		return
	var done := step_index
	EventBus.mission_step_completed.emit(active_mission.mission_id, done)
	step_index += 1
	if step_index >= active_mission.step_ids.size():
		_finish()


func _finish() -> void:
	if active_mission == null:
		return
	var finished := active_mission
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	if camp:
		camp.add_murmuring(finished.murmuring_impact, "")
	EventBus.mission_completed.emit(finished.mission_id)
	EventBus.notification.emit("%s complete." % finished.title)
	index += 1
	active_mission = null
	call_deferred("start_active")


func _step_label(step: String) -> String:
	match step:
		"gather_manna":
			var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
			var have := 0
			if camp:
				have = camp.manna_gathered_total - gather_baseline
			return "Gather manna  %d / %d" % [maxi(have, 0), active_mission.goal_amount]
		"reach_site":
			return "Go there"
		"purify":
			return "Sweeten the water"
		"ritual":
			return "Offer incense"
		_:
			return step


func _authority() -> bool:
	return not NetworkManager.online() or multiplayer.is_server()
