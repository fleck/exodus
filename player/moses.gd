extends CoopController

var _channel_lockout: float = 0.0


func _process_role(delta: float) -> void:
	super._process_role(delta)
	if _channel_lockout > 0.0:
		_channel_lockout -= delta
	braced_by_aaron()
	var site := _nearest_in_group("miracle_site", 3.6)
	var want := _wants_channel()
	if want and site != null and _channel_lockout <= 0.0 and (stamina > 0.5 or _braced):
		is_channeling = true
		if _braced:
			stamina = minf(stamina_max, stamina + 18.0 * delta)
		else:
			stamina = maxf(0.0, stamina - 22.0 * delta)
		if stamina <= 0.0 and not _braced:
			is_channeling = false
			_channel_lockout = 2.8
			EventBus.notification.emit("Moses can no longer hold up his hands.")
	else:
		is_channeling = false


func _ai_duty(delta: float) -> bool:
	var site := _desired_site()
	if site == null:
		return false
	if global_position.distance_to(site.global_position) > 2.8:
		_steer_to(site.global_position, delta, move_speed)
		return true
	_halt(delta)
	return true


func ability_hint() -> String:
	return "Hold ability at the rock or on the hill to channel. You cannot walk while channeling. Aaron can brace you."


func _wants_channel() -> bool:
	if is_possessed_by_local_human:
		return hold_ability
	return _desired_site() != null


func _desired_site() -> Node3D:
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	if missions and missions.active_mission and missions.active_mission.synergy:
		return _site_named("hill")
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	if camp and camp.water <= 4 and camp.rock_ready:
		return _site_named("rock")
	return null


func _site_named(site_id: String) -> Node3D:
	for node in get_tree().get_nodes_in_group("miracle_site"):
		if str(node.get("site_id")) == site_id:
			return node as Node3D
	return null


var _braced: bool = false


func braced_by_aaron() -> void:
	var aaron := SessionManager.leader(&"Aaron") as CoopController
	_braced = (
		aaron != null
		and aaron.is_bracing
		and global_position.distance_to(aaron.global_position) < 3.6
	)
