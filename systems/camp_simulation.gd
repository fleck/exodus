class_name CampSimulation
extends Node
## Hunger, thirst, spoil, murmuring, riot, and idolatry.
## The host simulates. Clients render the published snapshot.

const DAY_SECONDS := 210.0
const DAILY_MANNA := 10.0
const DAILY_WATER := 6.0
const POPULATION := 603550

var murmuring: float = 18.0
var water: int = 5
var wood: int = 2
var day: int = 1
var hour: float = 6.15
var manna_stacks: Array[Dictionary] = []
var manna_gathered_total: int = 0
var riot_active: bool = false
var riot_lockout: float = 0.0
var idolatry_active: bool = false
var idolatry_progress: float = 0.0
var idolatry_lockout: float = 0.0
var game_over: bool = false
var game_over_reason: String = ""
var marah_purified: bool = false
var marah_draws: int = 0
var rock_ready: bool = true
var chopped: Array[int] = []

var _hunger_note := false
var _thirst_note := false
var _grumble_note := false
var _unattended_note := false
var _unattended := 0.0
var _net_timer := 0.0


func _ready() -> void:
	add_to_group("camp")
	_load_items()
	manna_stacks = [{"amount": 4.0, "day": day, "protected": false}]
	if _authority():
		call_deferred("_announce_open")


func _process(delta: float) -> void:
	if not _authority():
		return
	if game_over:
		return
	if riot_lockout > 0.0:
		riot_lockout = maxf(0.0, riot_lockout - delta)
	if idolatry_lockout > 0.0:
		idolatry_lockout = maxf(0.0, idolatry_lockout - delta)
	_advance_clock(delta)
	_consume(delta)
	_attendance(delta)
	_idolatry(delta)
	if NetworkManager.online():
		_net_timer += delta
		if _net_timer >= 0.25:
			_net_timer = 0.0
			publish_state()


func pressure() -> float:
	return 0.75 + 0.25 * float(SessionManager.pressure_peers())


func manna_total() -> int:
	var total := 0.0
	for stack in manna_stacks:
		total += float(stack.get("amount", 0.0))
	return int(floor(total))


func manna_at_risk() -> int:
	if is_sabbath_eve():
		return 0
	var total := 0.0
	for stack in manna_stacks:
		if not bool(stack.get("protected", false)):
			total += float(stack.get("amount", 0.0))
	return int(ceil(total))


func is_sabbath() -> bool:
	return day % 7 == 0


func is_sabbath_eve() -> bool:
	return day % 7 == 6


func gather_multiplier() -> float:
	if murmuring >= 50.0:
		return 0.5
	if murmuring >= 25.0:
		return 0.75
	return 1.0


func clock_string() -> String:
	var whole := int(floor(hour)) % 24
	var minutes := int(floor((hour - float(whole)) * 60.0))
	var mark := ""
	if is_sabbath():
		mark = "  ·  Sabbath"
	elif is_sabbath_eve():
		mark = "  ·  Sabbath eve"
	return "Day %d    %02d:%02d%s" % [day, whole, minutes, mark]


func population_string() -> String:
	return "Camp  %s" % _comma(POPULATION)


func add_manna(amount: int) -> void:
	if not _authority():
		_rpc_add_manna.rpc_id(1, amount)
		return
	var qty := maxi(amount, 0)
	if qty == 0:
		return
	manna_stacks.append({
		"amount": float(qty),
		"day": day,
		"protected": is_sabbath_eve(),
	})
	manna_gathered_total += qty
	_hunger_note = false
	_emit(&"manna")


func add_water(amount: int) -> void:
	if not _authority():
		_rpc_add_water.rpc_id(1, amount)
		return
	water = maxi(0, water + amount)
	if water > 0:
		_thirst_note = false
	_emit(&"water")


func add_wood(amount: int) -> void:
	if not _authority():
		_rpc_add_wood.rpc_id(1, amount)
		return
	wood = maxi(0, wood + amount)
	_emit(&"wood")


func chop_tree(tree_id: int) -> bool:
	if not _authority():
		_rpc_chop.rpc_id(1, tree_id)
		return true
	if chopped.has(tree_id):
		return false
	chopped.append(tree_id)
	wood += 1
	_emit(&"wood")
	EventBus.world_flags_changed.emit()
	announce("Acacia cut for the camp.")
	return true


func purify_marah(by_name: String) -> bool:
	if not _authority():
		_rpc_purify.rpc_id(1, by_name)
		return true
	if marah_purified:
		return draw_marah()
	if by_name != "Miriam":
		if wood <= 0:
			add_murmuring(7.0, "Bitter water from Marah sickened the drinkers.")
			return true
		wood -= 1
		_emit(&"wood")
	marah_purified = true
	marah_draws = 1
	water += 8
	_thirst_note = false
	_emit(&"water")
	EventBus.water_purified.emit(8)
	EventBus.objective_event.emit(&"purify")
	EventBus.world_flags_changed.emit()
	announce("The bitter water grew sweet.")
	return true


func draw_marah() -> bool:
	if not marah_purified:
		return false
	if marah_draws <= 0:
		announce("The pool needs the night to gather again.")
		return false
	marah_draws -= 1
	water += 6
	_thirst_note = false
	_emit(&"water")
	announce("Waterskins filled at Marah.")
	return true


func grant_spring() -> void:
	if not _authority() or not rock_ready:
		return
	rock_ready = false
	water += 10
	_thirst_note = false
	_emit(&"water")
	EventBus.miracle_channeled.emit(&"Moses", &"rock")
	EventBus.world_flags_changed.emit()
	announce("Water broke from the rock.")


func add_murmuring(amount: float, reason: String = "") -> void:
	if not _authority():
		_rpc_murmur.rpc_id(1, amount, reason)
		return
	_add_murmuring_local(amount, reason)


func still_the_camp(amount: float, reason: String) -> void:
	if not _authority():
		_rpc_still.rpc_id(1, amount, reason)
		return
	riot_lockout = 30.0
	_end_riot()
	_add_murmuring_local(-absf(amount), reason)


func disrupt_idolatry(amount: float) -> void:
	if not _authority():
		_rpc_disrupt.rpc_id(1, amount)
		return
	if not idolatry_active:
		return
	idolatry_progress = maxf(0.0, idolatry_progress - amount)
	if idolatry_progress <= 0.0:
		idolatry_active = false
		idolatry_lockout = 45.0
		EventBus.idolatry_stopped.emit()
		_add_murmuring_local(-8.0, "The idol was torn down.")


func announce(text: String) -> void:
	if text == "":
		return
	EventBus.notification.emit(text)
	if NetworkManager.online() and multiplayer.is_server():
		_rpc_announce.rpc(text)


func publish_state() -> void:
	if not NetworkManager.online() or not multiplayer.is_server():
		return
	_rpc_state.rpc(
		murmuring,
		water,
		wood,
		day,
		hour,
		riot_active,
		idolatry_active,
		idolatry_progress,
		game_over,
		game_over_reason,
		manna_gathered_total,
		marah_purified,
		rock_ready,
		marah_draws,
		_pack_stacks(),
		_pack_chopped(),
		_mission_pack()
	)


func _announce_open() -> void:
	announce("Dawn on the sand. The manna will not keep.")
	_emit(&"manna")
	_emit(&"water")
	_emit(&"wood")
	EventBus.murmuring_changed.emit(murmuring)


func _advance_clock(delta: float) -> void:
	var previous := hour
	hour += (24.0 / DAY_SECONDS) * delta
	var wrapped := false
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		wrapped = true
		EventBus.day_advanced.emit(day, is_sabbath_eve())
	if (wrapped and hour >= 6.0) or (previous < 6.0 and hour >= 6.0):
		_on_dawn()


func _on_dawn() -> void:
	var spoiled := 0.0
	var kept: Array[Dictionary] = []
	for stack in manna_stacks:
		if bool(stack.get("protected", false)):
			kept.append({
				"amount": float(stack.get("amount", 0.0)),
				"day": int(stack.get("day", day)),
				"protected": false,
			})
		else:
			spoiled += float(stack.get("amount", 0.0))
	manna_stacks = kept
	rock_ready = true
	if marah_purified:
		marah_draws = 1
	EventBus.world_flags_changed.emit()
	if spoiled >= 1.0:
		EventBus.manna_spoiled.emit()
		_add_murmuring_local(spoiled * 0.7, "The leftover manna bred worms and stank.")
	var falls := not is_sabbath()
	EventBus.dawn_reached.emit(day, falls)
	if falls:
		announce("Dawn. Manna lies on the sand around the camp.")
	else:
		announce("Sabbath morning. No manna lies on the ground.")
	_emit(&"manna")


func _consume(delta: float) -> void:
	var scale := pressure()
	var before_manna := manna_total()
	var manna_need := (DAILY_MANNA / DAY_SECONDS) * delta * scale
	var got_manna := _drain_manna(manna_need)
	if got_manna + 0.0001 < manna_need:
		_add_murmuring_local((16.0 / DAY_SECONDS) * delta * scale, "")
		if manna_total() == 0 and not _hunger_note:
			_hunger_note = true
			announce("The baskets are empty. Hunger is spreading.")
	elif manna_total() > 2:
		_hunger_note = false
	if manna_total() != before_manna:
		_emit(&"manna")

	var water_need := (DAILY_WATER / DAY_SECONDS) * delta * scale
	_water_debt += water_need
	if _water_debt >= 1.0 and water > 0:
		var take := mini(water, int(floor(_water_debt)))
		water -= take
		_water_debt -= float(take)
		_emit(&"water")
		_thirst_note = false
	if water <= 0 and _water_debt > 0.05:
		_add_murmuring_local((18.0 / DAY_SECONDS) * delta * scale, "")
		if not _thirst_note:
			_thirst_note = true
			announce("The waterskins are dry.")
	if manna_total() > 0 and water > 0 and not riot_active and not idolatry_active:
		_add_murmuring_local((-1.4 / DAY_SECONDS) * delta, "")


var _water_debt: float = 0.0


func _attendance(delta: float) -> void:
	var near := false
	for leader in get_tree().get_nodes_in_group("leaders"):
		if leader is Node3D and (leader as Node3D).global_position.distance_to(Sites.CAMP) <= 30.0:
			near = true
			break
	if near:
		_unattended = 0.0
		_unattended_note = false
		return
	_unattended += delta
	if _unattended < 8.0:
		return
	_add_murmuring_local((12.0 / DAY_SECONDS) * delta * pressure(), "")
	if not _unattended_note:
		_unattended_note = true
		announce("The camp is unattended. Murmuring is rising.")


func _idolatry(delta: float) -> void:
	if not idolatry_active:
		return
	idolatry_progress += (100.0 / 30.0) * delta * pressure()
	if idolatry_progress >= 100.0:
		_lose("The calf was finished, and the camp broke.")


func _drain_manna(amount: float) -> float:
	var need := amount
	for i in manna_stacks.size():
		if need <= 0.0:
			break
		var stack: Dictionary = manna_stacks[i]
		var have := float(stack.get("amount", 0.0))
		var take := minf(have, need)
		stack["amount"] = have - take
		manna_stacks[i] = stack
		need -= take
	var index := manna_stacks.size() - 1
	while index >= 0:
		if float(manna_stacks[index].get("amount", 0.0)) <= 0.05:
			manna_stacks.remove_at(index)
		index -= 1
	return amount - need


func _add_murmuring_local(amount: float, reason: String) -> void:
	if game_over or absf(amount) < 0.0001:
		return
	var before := murmuring
	murmuring = clampf(murmuring + amount, 0.0, 100.0)
	if not is_equal_approx(before, murmuring):
		EventBus.murmuring_changed.emit(murmuring)
	if reason != "":
		announce(reason)
	_refresh_thresholds()


func _refresh_thresholds() -> void:
	if game_over:
		return
	if murmuring >= 100.0:
		_lose("The people revolted and turned back toward Egypt.")
		return
	if murmuring >= 75.0 and not idolatry_active and idolatry_lockout <= 0.0:
		idolatry_active = true
		idolatry_progress = maxf(idolatry_progress, 8.0)
		EventBus.idolatry_started.emit(Sites.CALF)
		announce("Gold is being gathered for a calf.")
	if murmuring >= 50.0 and not riot_active and riot_lockout <= 0.0:
		riot_active = true
		EventBus.riot_triggered.emit(Sites.CAMP)
		announce("The camp has broken into riots.")
	if murmuring < 45.0 and riot_active:
		_end_riot()
	if murmuring >= 25.0 and not _grumble_note:
		_grumble_note = true
		announce("A grumble moves through the tents.")
	if murmuring < 18.0:
		_grumble_note = false


func _end_riot() -> void:
	if not riot_active:
		return
	riot_active = false
	EventBus.riot_ended.emit()


func _lose(reason: String) -> void:
	if game_over:
		return
	game_over = true
	game_over_reason = reason
	murmuring = 100.0
	EventBus.rebellion.emit()
	EventBus.game_over.emit(reason)
	EventBus.murmuring_changed.emit(murmuring)
	publish_state()


func _emit(kind: StringName) -> void:
	var amount := 0
	match kind:
		&"manna":
			amount = manna_total()
		&"water":
			amount = water
		&"wood":
			amount = wood
	EventBus.resource_updated.emit(kind, amount)


func _authority() -> bool:
	return not NetworkManager.online() or multiplayer.is_server()


func _load_items() -> void:
	for path in [
		"res://resources/items/manna.tres",
		"res://resources/items/bitter_water.tres",
		"res://resources/items/wood.tres",
		"res://resources/items/gold.tres",
	]:
		var item := load(path) as ItemResource
		if item == null:
			push_warning("Missing item resource %s" % path)


func _pack_stacks() -> Array:
	var packed: Array = []
	for stack in manna_stacks:
		packed.append([
			float(stack.get("amount", 0.0)),
			int(stack.get("day", day)),
			bool(stack.get("protected", false)),
		])
	return packed


func _pack_chopped() -> Array:
	var packed: Array = []
	for tree_id in chopped:
		packed.append(tree_id)
	return packed


func _mission_pack() -> Dictionary:
	var missions := get_tree().get_first_node_in_group("missions")
	if missions and missions.has_method("pack_state"):
		return missions.call("pack_state")
	return {}


func _apply_state(
	new_murmur: float,
	new_water: int,
	new_wood: int,
	new_day: int,
	new_hour: float,
	new_riot: bool,
	new_idol: bool,
	new_idol_p: float,
	new_over: bool,
	new_reason: String,
	new_gathered: int,
	new_marah: bool,
	new_rock: bool,
	new_draws: int,
	stacks: Array,
	chopped_ids: Array,
	mission: Dictionary
) -> void:
	var was_over := game_over
	murmuring = new_murmur
	water = new_water
	wood = new_wood
	day = new_day
	hour = new_hour
	riot_active = new_riot
	idolatry_active = new_idol
	idolatry_progress = new_idol_p
	game_over = new_over
	game_over_reason = new_reason
	manna_gathered_total = new_gathered
	marah_purified = new_marah
	rock_ready = new_rock
	marah_draws = new_draws
	manna_stacks.clear()
	for entry in stacks:
		if entry is Array and (entry as Array).size() >= 3:
			manna_stacks.append({
				"amount": float(entry[0]),
				"day": int(entry[1]),
				"protected": bool(entry[2]),
			})
	chopped.clear()
	for tree_id in chopped_ids:
		chopped.append(int(tree_id))
	var missions := get_tree().get_first_node_in_group("missions")
	if missions and missions.has_method("apply_state"):
		missions.call("apply_state", mission)
	EventBus.world_flags_changed.emit()
	EventBus.murmuring_changed.emit(murmuring)
	if game_over and not was_over:
		EventBus.game_over.emit(game_over_reason)


func _comma(value: int) -> String:
	var text := str(value)
	var grouped := ""
	while text.length() > 3:
		grouped = "," + text.substr(text.length() - 3, 3) + grouped
		text = text.substr(0, text.length() - 3)
	return text + grouped


@rpc("any_peer", "reliable")
func _rpc_add_manna(amount: int) -> void:
	if multiplayer.is_server():
		add_manna(amount)


@rpc("any_peer", "reliable")
func _rpc_add_water(amount: int) -> void:
	if multiplayer.is_server():
		add_water(amount)


@rpc("any_peer", "reliable")
func _rpc_add_wood(amount: int) -> void:
	if multiplayer.is_server():
		add_wood(amount)


@rpc("any_peer", "reliable")
func _rpc_chop(tree_id: int) -> void:
	if multiplayer.is_server():
		chop_tree(tree_id)


@rpc("any_peer", "reliable")
func _rpc_purify(by_name: String) -> void:
	if multiplayer.is_server():
		purify_marah(by_name)


@rpc("any_peer", "reliable")
func _rpc_murmur(amount: float, reason: String) -> void:
	if multiplayer.is_server():
		add_murmuring(amount, reason)


@rpc("any_peer", "reliable")
func _rpc_still(amount: float, reason: String) -> void:
	if multiplayer.is_server():
		still_the_camp(amount, reason)


@rpc("any_peer", "reliable")
func _rpc_disrupt(amount: float) -> void:
	if multiplayer.is_server():
		disrupt_idolatry(amount)


@rpc("authority", "call_remote", "reliable")
func _rpc_announce(text: String) -> void:
	EventBus.notification.emit(text)


@rpc("authority", "call_remote", "unreliable")
func _rpc_state(
	new_murmur: float,
	new_water: int,
	new_wood: int,
	new_day: int,
	new_hour: float,
	new_riot: bool,
	new_idol: bool,
	new_idol_p: float,
	new_over: bool,
	new_reason: String,
	new_gathered: int,
	new_marah: bool,
	new_rock: bool,
	new_draws: int,
	stacks: Array,
	chopped_ids: Array,
	mission: Dictionary
) -> void:
	_apply_state(
		new_murmur, new_water, new_wood, new_day, new_hour,
		new_riot, new_idol, new_idol_p, new_over, new_reason,
		new_gathered, new_marah, new_rock, new_draws,
		stacks, chopped_ids, mission
	)
