extends Control

const WORLD := "res://scenes/world/wilderness.tscn"
const NAV_DEADZONE := 0.5
const NAV_REPEAT_DELAY := 0.38
const NAV_REPEAT_RATE := 0.14

var _status: Label
var _address: LineEdit
var _menu_items: Array[Control] = []
var _nav_dir := Vector2i.ZERO
var _nav_delay := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_controller_accept()
	SessionManager.reset()
	NetworkManager.close()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_paint()
	if OS.get_environment("EXODUS_AUTOPLAY") == "1":
		call_deferred("_start_local", 1)


func _paint() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.18, 0.22, 0.34)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var sand := ColorRect.new()
	sand.color = Color(0.55, 0.4, 0.24)
	sand.set_anchors_preset(Control.PRESET_FULL_RECT)
	sand.offset_top = 360
	sand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sand)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_left = -280
	column.offset_top = -280
	column.offset_right = 280
	column.offset_bottom = 280
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := Label.new()
	title.text = "EXODUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.96, 0.9, 0.75))
	column.add_child(title)
	var sub := Label.new()
	sub.text = "WILDERNESS"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.86, 0.68, 0.36))
	column.add_child(sub)
	var blurb := Label.new()
	blurb.text = "Guide the camp across the Sinai. One to four leaders.\nKeep them fed, watered, and from turning back."
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(blurb)

	var one := _button("One leader", _start_local.bind(1))
	var two := _button("Two leaders", _start_local.bind(2))
	var three := _button("Three leaders", _start_local.bind(3))
	var four := _button("Four leaders", _start_local.bind(4))
	column.add_child(one)
	column.add_child(two)
	column.add_child(three)
	column.add_child(four)

	var net := HBoxContainer.new()
	net.add_theme_constant_override("separation", 8)
	column.add_child(net)
	var host := _button("Host camp", _host)
	net.add_child(host)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.custom_minimum_size = Vector2(160, 0)
	_address.placeholder_text = "Address"
	net.add_child(_address)
	var join := _button("Join", _join)
	net.add_child(join)

	var touch := CheckButton.new()
	touch.text = "Touch controls"
	touch.button_pressed = SessionManager.show_touch
	touch.toggled.connect(func(on: bool) -> void: SessionManager.show_touch = on)
	column.add_child(touch)
	_wire_menu([one, two, three, four], [host, _address, join], [touch])

	var help := Label.new()
	help.text = "Menu: left stick or D-pad, south button to confirm. Mouse still works.\nSolo: WASD, mouse or right stick to turn the camera, E interact, R ability, F attack, 1–4 swap leaders.\nSecond leader: IJKL, numpad 8/4/6/2 camera, U interact, O ability, P attack. Further leaders use gamepads.\nUnassigned leaders follow as companions."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.9, 0.84, 0.72))
	column.add_child(help)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(callback)
	return button


func _ensure_controller_accept() -> void:
	for event in InputMap.action_get_events(&"ui_accept"):
		if event is InputEventJoypadButton:
			var existing := event as InputEventJoypadButton
			if existing.button_index == JOY_BUTTON_A and existing.device == -1:
				return
	var joy := InputEventJoypadButton.new()
	joy.device = -1
	joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"ui_accept", joy)


func _wire_menu(before: Array[Control], row: Array[Control], after: Array[Control]) -> void:
	_menu_items.clear()
	_menu_items.append_array(before)
	_menu_items.append_array(row)
	_menu_items.append_array(after)
	for item in _menu_items:
		_prepare_focusable(item)
		item.focus_neighbor_left = NodePath(".")
		item.focus_neighbor_right = NodePath(".")
	var column: Array[Control] = []
	column.append_array(before)
	column.append(row[0])
	column.append_array(after)
	_chain_focus(column, true, true)
	_chain_focus(row, false, false)
	var above := before[before.size() - 1]
	var below := after[0]
	for item in row:
		item.focus_neighbor_top = item.get_path_to(above)
		item.focus_neighbor_bottom = item.get_path_to(below)
	call_deferred("_focus_default")


func _chain_focus(items: Array[Control], vertical: bool, wrap: bool) -> void:
	var count := items.size()
	for i in count:
		var item := items[i]
		var prev_index := i - 1
		var next_index := i + 1
		if prev_index < 0:
			prev_index = count - 1 if wrap else -1
		if next_index >= count:
			next_index = 0 if wrap else -1
		if vertical:
			if prev_index >= 0:
				item.focus_neighbor_top = item.get_path_to(items[prev_index])
			if next_index >= 0:
				item.focus_neighbor_bottom = item.get_path_to(items[next_index])
		else:
			if prev_index >= 0:
				item.focus_neighbor_left = item.get_path_to(items[prev_index])
			if next_index >= 0:
				item.focus_neighbor_right = item.get_path_to(items[next_index])


func _prepare_focusable(item: Control) -> void:
	item.focus_mode = Control.FOCUS_ALL
	item.mouse_entered.connect(_hover_focus.bind(item))
	if item is BaseButton:
		item.add_theme_color_override("font_focus_color", Color(0.98, 0.9, 0.55))
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = Color(0.96, 0.84, 0.42)
		ring.set_border_width_all(2)
		ring.set_corner_radius_all(4)
		item.add_theme_stylebox_override("focus", ring)


func _hover_focus(item: Control) -> void:
	if is_instance_valid(item):
		item.grab_focus()


func _focus_default() -> void:
	if _menu_items.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and _menu_items.has(owner):
		return
	_menu_items[0].grab_focus()


func _process(delta: float) -> void:
	var wish := _menu_direction()
	if wish == Vector2i.ZERO:
		_nav_dir = Vector2i.ZERO
		_nav_delay = 0.0
		return
	if wish != _nav_dir:
		_nav_dir = wish
		_nav_delay = NAV_REPEAT_DELAY
		_move_focus(wish)
		return
	_nav_delay -= delta
	if _nav_delay <= 0.0:
		_nav_delay = NAV_REPEAT_RATE
		_move_focus(wish)


func _input(event: InputEvent) -> void:
	# Default UI actions also read the stick and D-pad. Swallow those events so a held stick steps once per repeat instead of once per motion event.
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_LEFT_Y:
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		match button.button_index:
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				get_viewport().set_input_as_handled()


func _menu_direction() -> Vector2i:
	var best := Vector2.ZERO
	for pad in Input.get_connected_joypads():
		var dpad := Vector2(
			float(int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT))),
			float(int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)))
		)
		if dpad != Vector2.ZERO:
			best = dpad
			break
		var stick := Vector2(
			Input.get_joy_axis(pad, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		)
		if stick.length() > best.length():
			best = stick
	if best.length() <= NAV_DEADZONE:
		return Vector2i.ZERO
	if absf(best.y) >= absf(best.x):
		return Vector2i(0, 1 if best.y > 0.0 else -1)
	return Vector2i(1 if best.x > 0.0 else -1, 0)


func _move_focus(dir: Vector2i) -> void:
	if _menu_items.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	if current == null or not _menu_items.has(current):
		_menu_items[0].grab_focus()
		return
	var neighbor := NodePath()
	if dir.y > 0:
		neighbor = current.focus_neighbor_bottom
	elif dir.y < 0:
		neighbor = current.focus_neighbor_top
	elif dir.x > 0:
		neighbor = current.focus_neighbor_right
	elif dir.x < 0:
		neighbor = current.focus_neighbor_left
	if neighbor.is_empty():
		return
	var next := current.get_node_or_null(neighbor) as Control
	if next == null or next == current or not _menu_items.has(next):
		return
	next.grab_focus()


func _start_local(count: int) -> void:
	SessionManager.start_local(count)
	get_tree().change_scene_to_file(WORLD)


func _host() -> void:
	var err := NetworkManager.host_game()
	if err != OK:
		_status.text = NetworkManager.last_error if NetworkManager.last_error != "" else error_string(err)
		return
	SessionManager.start_online_host()
	_status.text = "Hosting on port %d." % NetworkManager.PORT
	get_tree().change_scene_to_file(WORLD)


func _join() -> void:
	var ip := _address.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var err := NetworkManager.join_game(ip)
	if err != OK:
		_status.text = NetworkManager.last_error if NetworkManager.last_error != "" else error_string(err)
		return
	_status.text = "Looking for the camp..."
	multiplayer.connected_to_server.connect(_on_joined, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_join_failed, CONNECT_ONE_SHOT)


func _on_joined() -> void:
	SessionManager.start_online_client()
	get_tree().change_scene_to_file(WORLD)


func _on_join_failed() -> void:
	_status.text = "No camp answered."
	NetworkManager.close()
