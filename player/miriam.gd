extends CoopController

var song_cd: float = 0.0


func _process_role(delta: float) -> void:
	super._process_role(delta)
	if song_cd > 0.0:
		song_cd = maxf(0.0, song_cd - delta)
	if heal_pulse > 0.0:
		heal_pulse = maxf(0.0, heal_pulse - delta)
	if is_possessed_by_local_human and just_ability:
		_sing()


func _ai_duty(delta: float) -> bool:
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	if camp and camp.riot_active and song_cd <= 0.0 and stamina >= 30.0:
		_sing()
		_halt(delta)
		return true
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	var synergy := missions and missions.active_mission and missions.active_mission.synergy
	if synergy:
		if global_position.distance_to(Sites.VALLEY) > 7.0:
			_steer_to(Sites.VALLEY, delta, move_speed)
			return true
		if heal_pulse < 0.6:
			_sing()
		_halt(delta)
		return true
	var flake := _nearest_in_group("manna", 24.0)
	if flake:
		if global_position.distance_to(flake.global_position) > 1.5:
			_steer_to(flake.global_position, delta, move_speed)
			return true
		flake.call("interact", self)
		_halt(delta)
		return true
	if camp and not camp.marah_purified:
		var spring := _nearest_in_group("spring", 70.0)
		if spring:
			if global_position.distance_to(spring.global_position) > 2.2:
				_steer_to(spring.global_position, delta, move_speed)
				return true
			spring.call("interact", self)
			_halt(delta)
			return true
	return false


func ability_hint() -> String:
	return "Interact to gather, draw water, or purify. Ability sings. A song halts a riot and carries over the wounded."


func _sing() -> void:
	if song_cd > 0.0:
		return
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	var synergy := missions and missions.active_mission and missions.active_mission.synergy
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	if synergy:
		if stamina < 12.0:
			return
		stamina -= 12.0
		song_cd = 2.4
		heal_pulse = 3.0
		return
	if stamina < 30.0:
		return
	stamina -= 30.0
	song_cd = 16.0
	heal_pulse = 3.0
	if camp == null:
		return
	var strong := camp.riot_active or camp.murmuring >= 40.0
	camp.still_the_camp(16.0 if strong else 6.0, "Miriam sang, and the people listened.")
	camp.disrupt_idolatry(22.0)
