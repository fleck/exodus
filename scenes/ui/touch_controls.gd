extends CanvasLayer

var _stick: Control
var _knob: Control
var _dragging := false
var _pointer := -1


func _ready() -> void:
	layer = 30
	_build()
	SessionManager.show_touch = SessionManager.show_touch or DisplayServer.is_touchscreen_available()


func _process(_delta: float) -> void:
	visible = SessionManager.show_touch and SessionManager.local_controlled_count() >= 1
	if not _dragging:
		SessionManager.touch_move = SessionManager.touch_move.lerp(Vector2.ZERO, 0.35)


func _build() -> void:
	_stick = Control.new()
	_stick.custom_minimum_size = Vector2(180, 180)
	_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stick.offset_left = 36
	_stick.offset_top = -230
	_stick.offset_right = 216
	_stick.offset_bottom = -50
	_stick.gui_input.connect(_on_stick)
	add_child(_stick)
	var base := ColorRect.new()
	base.color = Color(0.1, 0.08, 0.05, 0.45)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.add_child(base)
	_knob = ColorRect.new()
	_knob.color = Color(0.9, 0.78, 0.45, 0.9)
	_knob.custom_minimum_size = Vector2(64, 64)
	_knob.position = Vector2(58, 58)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.add_child(_knob)
	_action_button("Interact", &"interact", Vector2(-210, -250))
	_action_button("Ability", &"channel_miracle", Vector2(-210, -150))
	_action_button("Attack", &"attack", Vector2(-100, -190))
	if SessionManager.requested_humans <= 1:
		_swap_row()


func _action_button(text: String, action: StringName, corner: Vector2) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 72)
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = corner.x
	button.offset_top = corner.y
	button.offset_right = corner.x + 96
	button.offset_bottom = corner.y + 72
	button.button_down.connect(func() -> void: SessionManager.set_touch_action(action, true))
	button.button_up.connect(func() -> void: SessionManager.set_touch_action(action, false))
	add_child(button)


func _swap_row() -> void:
	var names: Array[StringName] = [&"Moses", &"Aaron", &"Joshua", &"Miriam"]
	for i in names.size():
		var button := Button.new()
		button.text = String(names[i])
		button.position = Vector2(24 + i * 110, 18)
		button.custom_minimum_size = Vector2(100, 36)
		var who := names[i]
		button.pressed.connect(func() -> void: SessionManager.focus_character(who))
		add_child(button)


func _on_stick(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dragging = true
			_pointer = touch.index
			_move_knob(touch.position)
		elif touch.index == _pointer:
			_dragging = false
			_pointer = -1
			_knob.position = Vector2(58, 58)
			SessionManager.touch_move = Vector2.ZERO
	elif event is InputEventScreenDrag and _dragging:
		var drag := event as InputEventScreenDrag
		if drag.index == _pointer:
			_move_knob(drag.position)


func _move_knob(point: Vector2) -> void:
	var center := Vector2(90, 90)
	var delta := point - center
	delta = delta.limit_length(70.0)
	_knob.position = center + delta - Vector2(32, 32)
	SessionManager.touch_move = Vector2(delta.x / 70.0, delta.y / 70.0)
