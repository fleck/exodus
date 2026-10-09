extends Node
## Assigns the four leaders to local devices or network peers.
## Solo play swaps the possessed leader. Empty seats become companions.

enum PlayMode { SOLO, LOCAL, ONLINE }

const ORDER: Array[StringName] = [&"Moses", &"Aaron", &"Joshua", &"Miriam"]

var play_mode: PlayMode = PlayMode.SOLO
var requested_humans: int = 1
var split_screen: bool = false
var show_touch: bool = false
var touch_move: Vector2 = Vector2.ZERO
var touch_held: Dictionary = {}
var touch_just: Dictionary = {}

var _leaders: Dictionary = {}
var _inputs_ready := false


func _enter_tree() -> void:
	_register_inputs()
	show_touch = (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("mobile")
		or OS.has_feature("web")
	)
	if not multiplayer.peer_connected.is_connected(_on_net_peers_changed):
		multiplayer.peer_connected.connect(_on_net_peers_changed)
		multiplayer.peer_disconnected.connect(_on_net_peers_changed)


func _unhandled_input(event: InputEvent) -> void:
	if local_controlled_count() != 1:
		return
	if event.is_action_pressed(&"swap_1"):
		focus_character(&"Moses")
	elif event.is_action_pressed(&"swap_2"):
		focus_character(&"Aaron")
	elif event.is_action_pressed(&"swap_3"):
		focus_character(&"Joshua")
	elif event.is_action_pressed(&"swap_4"):
		focus_character(&"Miriam")


func reset() -> void:
	_leaders.clear()
	play_mode = PlayMode.SOLO
	requested_humans = 1
	split_screen = false
	touch_move = Vector2.ZERO
	touch_held.clear()
	touch_just.clear()


func start_local(count: int) -> void:
	_leaders.clear()
	requested_humans = clampi(count, 1, 4)
	play_mode = PlayMode.SOLO if requested_humans == 1 else PlayMode.LOCAL
	EventBus.peer_count_changed.emit(pressure_peers())


func start_online_host() -> void:
	_leaders.clear()
	play_mode = PlayMode.ONLINE
	requested_humans = 1
	EventBus.peer_count_changed.emit(1)


func start_online_client() -> void:
	_leaders.clear()
	play_mode = PlayMode.ONLINE
	requested_humans = NetworkManager.peer_total()
	EventBus.peer_count_changed.emit(requested_humans)


func register_leader(leader: Node) -> void:
	var key: StringName = leader.get("character_name")
	_leaders[key] = leader
	if not leader.is_in_group("leaders"):
		leader.add_to_group("leaders")
	if _leaders.size() == ORDER.size():
		call_deferred("_assign_possession")


func unregister_leader(leader: Node) -> void:
	var key: StringName = leader.get("character_name")
	if _leaders.get(key) == leader:
		_leaders.erase(key)


func leader(character_name: StringName) -> Node:
	return _leaders.get(character_name)


func leaders() -> Array:
	var found: Array = []
	for character_name in ORDER:
		if _leaders.has(character_name):
			found.append(_leaders[character_name])
	return found


func pressure_peers() -> int:
	var live := 0
	for character_name in _leaders:
		if int(_leaders[character_name].get("controlled_by_peer")) > 0:
			live += 1
	if live > 0:
		return live
	return maxi(requested_humans, 1)


func local_controlled_count() -> int:
	var count := 0
	for character_name in _leaders:
		if bool(_leaders[character_name].get("is_possessed_by_local_human")):
			count += 1
	return count


func focus_character(character_name: StringName) -> void:
	if local_controlled_count() != 1 and play_mode != PlayMode.SOLO:
		return
	if not _leaders.has(character_name):
		return
	for key in ORDER:
		if not _leaders.has(key):
			continue
		var body: Node = _leaders[key]
		if key == character_name:
			body.call("assign_control", NetworkManager.local_peer_id(), -1, 0)
		else:
			body.call("assign_control", 0, -1, 0)
	_refresh_follow_targets()
	_refresh_cameras()
	EventBus.character_swapped.emit(character_name)
	EventBus.control_changed.emit()


func set_touch_action(action: StringName, held: bool) -> void:
	var was: bool = bool(touch_held.get(action, false))
	touch_held[action] = held
	if held and not was:
		touch_just[action] = true


func consume_touch_just(action: StringName) -> bool:
	var pressed: bool = bool(touch_just.get(action, false))
	touch_just[action] = false
	return pressed


func _on_net_peers_changed(_id: int = 0) -> void:
	if play_mode != PlayMode.ONLINE:
		return
	requested_humans = NetworkManager.peer_total()
	EventBus.peer_count_changed.emit(requested_humans)
	if _leaders.size() == ORDER.size():
		_assign_possession()


func _assign_possession() -> void:
	if _leaders.size() < ORDER.size():
		return
	if play_mode == PlayMode.ONLINE:
		_assign_online()
	else:
		_assign_local()
	_refresh_follow_targets()
	_refresh_cameras()
	var focus_name: StringName = &"Moses"
	for character_name in ORDER:
		if bool(_leaders[character_name].get("is_possessed_by_local_human")):
			focus_name = character_name
			break
	EventBus.character_swapped.emit(focus_name)
	EventBus.control_changed.emit()
	EventBus.peer_count_changed.emit(pressure_peers())


func _assign_local() -> void:
	var devices := _local_devices()
	var used := mini(requested_humans, devices.size())
	if requested_humans > devices.size():
		EventBus.notification.emit(
			"%d control schemes found. The other leaders will follow as companions." % devices.size()
		)
	for i in ORDER.size():
		var body: Node = _leaders[ORDER[i]]
		if i < used:
			body.call("assign_control", 1, int(devices[i]["device"]), int(devices[i]["scheme"]))
		else:
			body.call("assign_control", 0, -1, 0)


func _assign_online() -> void:
	var ids: Array[int] = [1]
	for peer_id in multiplayer.get_peers():
		ids.append(int(peer_id))
	ids.sort()
	var me := NetworkManager.local_peer_id()
	var device := -1
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		device = int(pads[0])
	for i in ORDER.size():
		var body: Node = _leaders[ORDER[i]]
		if i < ids.size():
			var peer_id := ids[i]
			var use_device := device if peer_id == me else -1
			body.call("assign_control", peer_id, use_device, 0)
		else:
			body.call("assign_control", 0, -1, 0)


func _local_devices() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"device": -1, "scheme": 0},
		{"device": -1, "scheme": 1},
	]
	for pad in Input.get_connected_joypads():
		list.append({"device": int(pad), "scheme": 0})
	return list


func _refresh_follow_targets() -> void:
	var host: Node = null
	for character_name in ORDER:
		if not _leaders.has(character_name):
			continue
		var body: Node = _leaders[character_name]
		if int(body.get("controlled_by_peer")) > 0:
			host = body
			break
	for character_name in ORDER:
		if not _leaders.has(character_name):
			continue
		var body: Node = _leaders[character_name]
		if int(body.get("controlled_by_peer")) > 0:
			body.set("leader_target", null)
		else:
			body.set("leader_target", host)


func _refresh_cameras() -> void:
	split_screen = local_controlled_count() > 1 and play_mode != PlayMode.ONLINE
	var listener_set := false
	for character_name in ORDER:
		if not _leaders.has(character_name):
			continue
		var body: Node = _leaders[character_name]
		var use_listener := bool(body.get("is_possessed_by_local_human")) and not listener_set and not split_screen
		if use_listener:
			listener_set = true
		body.call("refresh_camera", split_screen, use_listener)


func _register_inputs() -> void:
	if _inputs_ready:
		return
	_inputs_ready = true
	_key(&"move_left", KEY_A)
	_key(&"move_left", KEY_LEFT)
	_key(&"move_right", KEY_D)
	_key(&"move_right", KEY_RIGHT)
	_key(&"move_up", KEY_W)
	_key(&"move_up", KEY_UP)
	_key(&"move_down", KEY_S)
	_key(&"move_down", KEY_DOWN)
	_key(&"interact", KEY_E)
	_key(&"channel_miracle", KEY_R)
	_key(&"attack", KEY_F)
	_mouse(&"attack", MOUSE_BUTTON_LEFT)
	_key(&"p2_move_left", KEY_J)
	_key(&"p2_move_right", KEY_L)
	_key(&"p2_move_up", KEY_I)
	_key(&"p2_move_down", KEY_K)
	_key(&"p2_interact", KEY_U)
	_key(&"p2_channel_miracle", KEY_O)
	_key(&"p2_attack", KEY_P)
	_key(&"swap_1", KEY_1)
	_key(&"swap_2", KEY_2)
	_key(&"swap_3", KEY_3)
	_key(&"swap_4", KEY_4)
	_joy(&"swap_1", JOY_BUTTON_DPAD_UP)
	_joy(&"swap_2", JOY_BUTTON_DPAD_RIGHT)
	_joy(&"swap_3", JOY_BUTTON_DPAD_DOWN)
	_joy(&"swap_4", JOY_BUTTON_DPAD_LEFT)
	_key(&"pause", KEY_ESCAPE)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _key(action: StringName, keycode: Key) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _joy(action: StringName, button: JoyButton) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = -1
	InputMap.action_add_event(action, event)
