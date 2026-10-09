extends CoopController

var _scout_cd: float = 0.0


func _process_role(delta: float) -> void:
	super._process_role(delta)
	if _scout_cd > 0.0:
		_scout_cd -= delta
	if is_possessed_by_local_human and hold_ability and stamina > 1.0:
		sprinting = true
		stamina = maxf(0.0, stamina - 9.0 * delta)
	if is_possessed_by_local_human and just_ability and _scout_cd <= 0.0:
		_scout()


func _ai_duty(delta: float) -> bool:
	var foe := _nearest_in_group("enemies", 26.0)
	if foe:
		if global_position.distance_to(foe.global_position) > attack_range() * 0.85:
			_steer_to(foe.global_position, delta, move_speed * 1.15)
			return true
		_perform_attack()
		_halt(delta)
		return true
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	if camp and camp.idolatry_active:
		var calf := _nearest_in_group("calf", 40.0)
		if calf:
			if global_position.distance_to(calf.global_position) > attack_range():
				_steer_to(calf.global_position, delta, move_speed)
				return true
			_perform_attack()
			_halt(delta)
			return true
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	if missions and missions.active_mission and missions.active_mission.synergy:
		if global_position.distance_to(Sites.VALLEY) > 8.0:
			_steer_to(Sites.VALLEY, delta, move_speed)
			return true
		_halt(delta)
		return true
	return false


func attack_damage() -> float:
	return 32.0


func attack_range() -> float:
	return 2.55


func attack_cooldown() -> float:
	return 0.48


func ability_hint() -> String:
	return "Attack to strike. Tap ability to scout. Hold ability to sprint."


func _scout() -> void:
	_scout_cd = 1.5
	var foe := _nearest_in_group("enemies", 120.0)
	if foe:
		EventBus.notification.emit("Joshua marks Amalekites to the %s." % _compass(foe.global_position))
		return
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	if missions and missions.active_mission:
		var pos: Vector3 = missions.active_mission.objective_coordinates
		EventBus.notification.emit("Joshua marks %s to the %s." % [missions.active_mission.title, _compass(pos)])
		return
	EventBus.notification.emit("Joshua finds no fresh track on the sand.")


func _compass(pos: Vector3) -> String:
	var offset := pos - global_position
	if absf(offset.x) > absf(offset.z):
		return "east" if offset.x > 0.0 else "west"
	return "south" if offset.z > 0.0 else "north"
