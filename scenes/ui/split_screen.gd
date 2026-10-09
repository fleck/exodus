extends CanvasLayer

var _views: Array[Dictionary] = []


func _ready() -> void:
	layer = 1
	EventBus.control_changed.connect(_rebuild)
	get_viewport().size_changed.connect(_rebuild)
	call_deferred("_rebuild")


func _process(_delta: float) -> void:
	for view in _views:
		var leader := view.leader as Node3D
		var camera := view.camera as Camera3D
		if leader == null or camera == null:
			continue
		var source := leader.get_node_or_null("CameraPivot/Camera3D") as Camera3D
		if source:
			camera.global_transform = source.global_transform


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_views.clear()
	var humans: Array[Node] = []
	for leader in SessionManager.leaders():
		if bool(leader.get("is_possessed_by_local_human")):
			humans.append(leader)
	if humans.size() <= 1:
		visible = false
		return
	visible = true
	var world := (get_parent() as Node3D).get_world_3d()
	var rect := get_viewport().get_visible_rect()
	var layouts := _layouts(humans.size(), rect)
	for i in humans.size():
		var frame := layouts[i]
		var container := SubViewportContainer.new()
		container.position = frame.position
		container.size = frame.size
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var viewport := SubViewport.new()
		viewport.own_world_3d = false
		viewport.world_3d = world
		viewport.size = Vector2i(maxi(int(frame.size.x), 8), maxi(int(frame.size.y), 8))
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.gui_disable_input = true
		var camera := Camera3D.new()
		camera.fov = 68.0
		camera.current = true
		viewport.add_child(camera)
		container.add_child(viewport)
		add_child(container)
		_views.append({leader = humans[i], camera = camera})


func _layouts(count: int, rect: Rect2) -> Array[Rect2]:
	var width := rect.size.x
	var height := rect.size.y
	if count <= 2:
		if height > width:
			return [Rect2(0, 0, width, height * 0.5), Rect2(0, height * 0.5, width, height * 0.5)]
		return [Rect2(0, 0, width * 0.5, height), Rect2(width * 0.5, 0, width * 0.5, height)]
	if count == 3:
		return [
			Rect2(0, 0, width * 0.5, height * 0.5),
			Rect2(width * 0.5, 0, width * 0.5, height * 0.5),
			Rect2(0, height * 0.5, width, height * 0.5),
		]
	return [
		Rect2(0, 0, width * 0.5, height * 0.5),
		Rect2(width * 0.5, 0, width * 0.5, height * 0.5),
		Rect2(0, height * 0.5, width * 0.5, height * 0.5),
		Rect2(width * 0.5, height * 0.5, width * 0.5, height * 0.5),
	]
