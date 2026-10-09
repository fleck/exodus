extends CanvasLayer

var _clock: Label
var _mission: Label
var _resources: Label
var _population: Label
var _murmur: ProgressBar
var _murmur_fill: StyleBoxFlat
var _status: Label
var _prompt: Label
var _hint: Label
var _synergy: Label
var _toasts: VBoxContainer
var _toast_rows: Array[Dictionary] = []
var _paused := false
var _pause_panel: PanelContainer
var _over_panel: PanelContainer
var _over_label: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	EventBus.notification.connect(_toast)
	EventBus.game_over.connect(_on_game_over)
	EventBus.character_swapped.connect(func(_name: StringName) -> void: _refresh())
	EventBus.mission_started.connect(func(_mission_res: Resource) -> void: _refresh())


func _process(delta: float) -> void:
	_refresh()
	var kept: Array[Dictionary] = []
	for row in _toast_rows:
		row.life = float(row.life) - delta
		var label: Label = row.label
		label.modulate.a = clampf(float(row.life), 0.0, 1.0)
		if float(row.life) > 0.0:
			kept.append(row)
		else:
			label.queue_free()
	_toast_rows = kept


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(stack)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top)
	_clock = _label(18)
	top.add_child(_clock)
	_mission = _label(18)
	_mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_mission)
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right)
	_resources = _label(16)
	_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_resources)
	_population = _label(14)
	_population.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_population)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)

	_synergy = _label(16)
	_synergy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_synergy)

	_murmur = preload("res://scenes/ui/murmuring_bar.tscn").instantiate()
	stack.add_child(_murmur)
	_murmur_fill = _murmur.get("fill_style") as StyleBoxFlat

	_status = _label(18)
	stack.add_child(_status)
	_prompt = _label(16)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	stack.add_child(_prompt)
	_hint = _label(13)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_hint)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_toasts.offset_left = 20
	_toasts.offset_top = -80
	_toasts.offset_right = 520
	_toasts.offset_bottom = 80
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_pause_panel = _center_panel()
	_pause_panel.visible = false
	var pause_box := _pause_panel.get_child(0).get_child(0) as VBoxContainer
	var pause_title := _label(28)
	pause_title.text = "Camp paused"
	pause_box.add_child(pause_title)
	var resume := Button.new()
	resume.text = "Return to the camp"
	resume.pressed.connect(_toggle_pause)
	pause_box.add_child(resume)
	var touch := CheckButton.new()
	touch.text = "Touch controls"
	touch.button_pressed = SessionManager.show_touch
	touch.toggled.connect(func(on: bool) -> void: SessionManager.show_touch = on)
	pause_box.add_child(touch)
	var menu := Button.new()
	menu.text = "Leave the wilderness"
	menu.pressed.connect(_leave)
	pause_box.add_child(menu)
	add_child(_pause_panel)

	_over_panel = _center_panel()
	_over_panel.visible = false
	var over_box := _over_panel.get_child(0).get_child(0) as VBoxContainer
	_over_label = _label(22)
	_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_over_label.custom_minimum_size = Vector2(420, 0)
	over_box.add_child(_over_label)
	var back := Button.new()
	back.text = "Return to the title"
	back.pressed.connect(_leave)
	over_box.add_child(back)
	add_child(_over_panel)


func _refresh() -> void:
	var camp := get_tree().get_first_node_in_group("camp") as CampSimulation
	var missions := get_tree().get_first_node_in_group("missions") as MissionManager
	if camp:
		_clock.text = camp.clock_string()
		var risk := camp.manna_at_risk()
		var risk_note := "" if risk <= 0 else "  (%d rots at dawn)" % risk
		_resources.text = "Manna %d%s\nWater %d    Wood %d" % [camp.manna_total(), risk_note, camp.water, camp.wood]
		_population.text = camp.population_string()
		_murmur.value = camp.murmuring
		_tint_murmur(camp.murmuring)
	if missions:
		_mission.text = missions.step_text()
		if missions.active_mission and missions.active_mission.synergy:
			var flags := missions.synergy_flags()
			_synergy.text = "Moses %s   Aaron %s   Joshua %s   Miriam %s" % [
				_mark(bool(flags["moses"])), _mark(bool(flags["aaron"])), _mark(bool(flags["joshua"])), _mark(bool(flags["miriam"]))
			]
		else:
			_synergy.text = ""
	var lines: PackedStringArray = []
	for leader in SessionManager.leaders():
		var body := leader as CoopController
		if body == null or not body.is_possessed_by_local_human:
			continue
		lines.append("%s  ·  %s  ·  stamina %d" % [body.character_name, body.status_line(), int(body.stamina)])
		var prompt := body.current_prompt()
		if prompt != "":
			lines.append(prompt)
	_status.text = "\n".join(lines)
	var hint_source := ""
	for leader in SessionManager.leaders():
		var body := leader as CoopController
		if body and body.is_possessed_by_local_human:
			hint_source = body.ability_hint() + "\n" + body.control_hint()
			if SessionManager.local_controlled_count() == 1:
				break
	_hint.text = hint_source


func _tint_murmur(level: float) -> void:
	if _murmur_fill == null:
		return
	if level >= 75.0:
		_murmur_fill.bg_color = Color(0.72, 0.16, 0.1)
	elif level >= 50.0:
		_murmur_fill.bg_color = Color(0.78, 0.38, 0.12)
	elif level >= 25.0:
		_murmur_fill.bg_color = Color(0.78, 0.62, 0.22)
	else:
		_murmur_fill.bg_color = Color(0.42, 0.58, 0.32)


func _toast(text: String) -> void:
	var label := _label(15)
	label.text = text
	_toasts.add_child(label)
	_toast_rows.append({"label": label, "life": 5.5})
	while _toast_rows.size() > 4:
		var old: Dictionary = _toast_rows.pop_front()
		(old.label as Label).queue_free()


func _on_game_over(reason: String) -> void:
	_over_label.text = reason
	_over_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _toggle_pause() -> void:
	if _over_panel.visible:
		return
	_paused = not _paused
	_pause_panel.visible = _paused
	get_tree().paused = _paused
	if _paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _leave() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.close()
	SessionManager.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _center_panel() -> PanelContainer:
	var center := PanelContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -240
	center.offset_top = -120
	center.offset_right = 240
	center.offset_bottom = 120
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	center.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.12, 0.08, 0.05, 0.94)
	panel.border_color = Color(0.8, 0.64, 0.32)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	center.add_theme_stylebox_override("panel", panel)
	return center


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _mark(on: bool) -> String:
	return "●" if on else "○"
