# player/input_router.gd
class_name InputRouter
extends Node
## Separates a local device from the network peer that owns the leader.
## device_id -1 reads the keyboard (and touch, for scheme 0).
## 0, 1, 2... read that joypad. Solo and split-screen call the same API.

@export var device_id: int = -1
@export var network_peer_id: int = 1
@export var keyboard_scheme: int = 0

var _joy_prev: Dictionary = {}


func get_movement_vector() -> Vector2:
	if not NetworkManager.has_authority(get_parent()):
		return Vector2.ZERO
	if device_id >= 0:
		var axis := Vector2(
			Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		)
		return axis if axis.length() > 0.2 else Vector2.ZERO
	var prefix := _prefix()
	var keys := Input.get_vector(
		prefix + "move_left",
		prefix + "move_right",
		prefix + "move_up",
		prefix + "move_down"
	)
	if keys == Vector2.ZERO and keyboard_scheme == 0:
		return SessionManager.touch_move
	return keys


func is_action_just_pressed(action_name: StringName) -> bool:
	if not NetworkManager.has_authority(get_parent()):
		return false
	if device_id == -1:
		var pressed := Input.is_action_just_pressed(_action(action_name))
		if keyboard_scheme == 0 and SessionManager.consume_touch_just(action_name):
			return true
		if action_name == &"attack" and pressed and _pointer_over_ui():
			return false
		return pressed
	var button := _map_action_to_button(action_name)
	if button == JOY_BUTTON_INVALID:
		return false
	var down := Input.is_joy_button_pressed(device_id, button)
	var was: bool = bool(_joy_prev.get(button, false))
	_joy_prev[button] = down
	return down and not was


func is_action_pressed(action_name: StringName) -> bool:
	if not NetworkManager.has_authority(get_parent()):
		return false
	if device_id == -1:
		var down := Input.is_action_pressed(_action(action_name))
		if keyboard_scheme == 0 and bool(SessionManager.touch_held.get(action_name, false)):
			return true
		return down
	var button := _map_action_to_button(action_name)
	if button == JOY_BUTTON_INVALID:
		return false
	return Input.is_joy_button_pressed(device_id, button)


func _map_action_to_button(action_name: StringName) -> JoyButton:
	match action_name:
		&"interact":
			return JOY_BUTTON_A
		&"channel_miracle":
			return JOY_BUTTON_RIGHT_SHOULDER
		&"attack":
			return JOY_BUTTON_X
		_:
			return JOY_BUTTON_INVALID


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
