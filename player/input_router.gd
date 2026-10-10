# player/input_router.gd
class_name InputRouter
extends Node
## Separates a local device from the network peer that owns the leader.
## device_id -1 reads the keyboard (and touch, for scheme 0).
## 0, 1, 2... read that joypad. Solo and split-screen call the same API.
## Keyboard player 1 also reads a joypad that no seat has claimed.

@export var device_id: int = -1
@export var network_peer_id: int = 1
@export var keyboard_scheme: int = 0

const TRIGGER_PRESS := 0.55

var _joy_prev: Dictionary = {}


func get_movement_vector() -> Vector2:
	if not NetworkManager.has_authority(get_parent()):
		return Vector2.ZERO
	if device_id >= 0:
		return _joy_move(device_id)
	var prefix := _prefix()
	var keys := Input.get_vector(
		prefix + "move_left",
		prefix + "move_right",
		prefix + "move_up",
		prefix + "move_down"
	)
	if keys == Vector2.ZERO and keyboard_scheme == 0:
		keys = SessionManager.touch_move
	var pad := _spare_pad()
	if pad >= 0:
		keys += _joy_move(pad)
	return keys.limit_length(1.0)


## Right stick, or the keyboard look keys. Y is positive when looking down.
func get_look_vector() -> Vector2:
	if not NetworkManager.has_authority(get_parent()):
		return Vector2.ZERO
	if device_id >= 0:
		return _joy_look(device_id)
	var keys := Input.get_vector(
		_action(&"look_left"),
		_action(&"look_right"),
		_action(&"look_up"),
		_action(&"look_down")
	)
	var pad := _spare_pad()
	if pad >= 0:
		keys += _joy_look(pad)
	return keys.limit_length(1.0)


func is_action_just_pressed(action_name: StringName) -> bool:
	if not NetworkManager.has_authority(get_parent()):
		return false
	if device_id >= 0:
		return _joy_just(device_id, action_name)
	var pressed := Input.is_action_just_pressed(_action(action_name))
	if action_name == &"attack" and pressed and _pointer_over_ui():
		pressed = false
	if keyboard_scheme == 0 and SessionManager.consume_touch_just(action_name):
		pressed = true
	if keyboard_scheme == 0:
		pressed = pressed or _joy_just(_spare_pad(), action_name)
	return pressed


func is_action_pressed(action_name: StringName) -> bool:
	if not NetworkManager.has_authority(get_parent()):
		return false
	if device_id >= 0:
		return _joy_held(device_id, action_name)
	var down := Input.is_action_pressed(_action(action_name))
	if keyboard_scheme == 0 and bool(SessionManager.touch_held.get(action_name, false)):
		down = true
	if keyboard_scheme == 0:
		down = down or _joy_held(_spare_pad(), action_name)
	return down


## Joypad this leader should read. Keyboard player 1 uses a pad no seat has claimed.
func active_pad() -> int:
	if device_id >= 0:
		return device_id
	return _spare_pad()


func _joy_just(pad: int, action_name: StringName) -> bool:
	if pad < 0:
		_joy_prev[action_name] = false
		return false
	var down := _joy_down(pad, action_name)
	var was: bool = bool(_joy_prev.get(action_name, false))
	_joy_prev[action_name] = down
	return down and not was


func _joy_held(pad: int, action_name: StringName) -> bool:
	if pad < 0:
		return false
	return _joy_down(pad, action_name)


## South button interacts. Right bumper is the ability (tap or hold).
## Right trigger attacks so the camera thumb can stay on the stick; west face does too.
func _joy_down(pad: int, action_name: StringName) -> bool:
	match action_name:
		&"interact":
			return Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
		&"channel_miracle":
			return Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER)
		&"attack":
			return (
				Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) >= TRIGGER_PRESS
				or Input.is_joy_button_pressed(pad, JOY_BUTTON_X)
			)
		_:
			return false


func _joy_move(pad: int) -> Vector2:
	var axis := Vector2(
		Input.get_joy_axis(pad, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
	)
	if axis.length() <= 0.2:
		return Vector2.ZERO
	return axis.limit_length(1.0)


func _joy_look(pad: int) -> Vector2:
	var axis := Vector2(
		Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
	)
	if axis.length() <= 0.2:
		return Vector2.ZERO
	return axis.limit_length(1.0)


## Keyboard player 1 can move and orbit with a controller that no seat has claimed.
func _spare_pad() -> int:
	if device_id >= 0 or keyboard_scheme != 0:
		return -1
	var taken: Dictionary = {}
	for leader in SessionManager.leaders():
		var router := leader.get_node_or_null("InputRouter") as InputRouter
		if router != null and router.device_id >= 0:
			taken[router.device_id] = true
	for pad in Input.get_connected_joypads():
		var id := int(pad)
		if not taken.has(id):
			return id
	return -1


func _prefix() -> String:
	if keyboard_scheme <= 0:
		return ""
	return "p%d_" % (keyboard_scheme + 1)


func _action(action_name: StringName) -> StringName:
	if keyboard_scheme <= 0:
		return action_name
	return StringName(_prefix() + String(action_name))


func _pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE
