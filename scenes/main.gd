extends Control

const WORLD := "res://scenes/world/wilderness.tscn"

var _status: Label
var _address: LineEdit


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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

	column.add_child(_button("One leader", _start_local.bind(1)))
	column.add_child(_button("Two leaders", _start_local.bind(2)))
	column.add_child(_button("Three leaders", _start_local.bind(3)))
	column.add_child(_button("Four leaders", _start_local.bind(4)))

	var net := HBoxContainer.new()
	net.add_theme_constant_override("separation", 8)
	column.add_child(net)
	net.add_child(_button("Host camp", _host))
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.custom_minimum_size = Vector2(160, 0)
	_address.placeholder_text = "Address"
	net.add_child(_address)
	net.add_child(_button("Join", _join))

	var touch := CheckButton.new()
	touch.text = "Touch controls"
	touch.button_pressed = SessionManager.show_touch
	touch.toggled.connect(func(on: bool) -> void: SessionManager.show_touch = on)
	column.add_child(touch)

	var help := Label.new()
	help.text = "Solo: WASD, mouse or right stick to turn the camera, E interact, R ability, F attack, 1–4 swap leaders.\nSecond leader: IJKL, numpad 8/4/6/2 camera, U interact, O ability, P attack. Further leaders use gamepads.\nUnassigned leaders follow as companions."
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
