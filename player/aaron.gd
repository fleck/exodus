extends CoopController

var ritual_timer: float = 0.0
var ritual_cd: float = 0.0


func _process_role(delta: float) -> void:
	if ritual_cd > 0.0:
		ritual_cd = maxf(0.0, ritual_cd - delta)
	if ritual_timer > 0.0:
		ritual_timer -= delta
		is_performing_ritual = ritual_timer > 0.0
	else:
		is_performing_ritual = false
	var moses := SessionManager.leader(&"Moses") as CoopController
	var near_moses := moses != null and global_position.distance_to(moses.global_position) < 3.4
	if is_performing_ritual:
		is_bracing = false
		return
	if is_possessed_by_local_human:
		is_bracing = hold_ability and near_moses
		super._process_role(delta)
	else:
		is_bracing = moses != null and moses.is_channeling and near_moses


func _ai_duty(delta: float) -> bool:
	if is_performing_ritual or is_bracing:
		_halt(delta)
		return true
	var moses := SessionManager.leader(&"Moses") as CoopController
	if moses and moses.is_channeling:
		_steer_to(moses.global_position, delta, move_speed)
		return true
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	if camp and camp.murmuring >= 46.0 and ritual_cd <= 0.0 and not camp.riot_active:
		var tent := _nearest_in_group("tabernacle", 80.0)
		if tent == null:
			return false
		if global_position.distance_to(tent.global_position) > 2.2:
			_steer_to(tent.global_position, delta, move_speed)
			return true
		begin_ritual()
		_halt(delta)
		return true
	return false


func set_ritual_cooldown(seconds: float) -> void:
	ritual_cd = seconds


func begin_ritual() -> void:
	if ritual_cd > 0.0 or ritual_timer > 0.0:
		if is_possessed_by_local_human:
			EventBus.notification.emit("The altar is not ready for another offering.")
		return
	ritual_timer = 2.5
	is_performing_ritual = true


func ability_hint() -> String:
	return "Hold ability beside Moses to brace him. Interact at the Tabernacle to offer incense."
