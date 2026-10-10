class_name WoodTree
extends CampInteractable

@export var tree_id: int = 1

var _cut := false


func _ready() -> void:
	super._ready()
	add_to_group("wood")
	EventBus.world_flags_changed.connect(_refresh)
	_build(false)


func _build(stump: bool) -> void:
	var old := get_node_or_null("Model")
	if old:
		remove_child(old)
		old.queue_free()
	var model := Node3D.new()
	model.name = "Model"
	model.rotation_degrees = Vector3(0, float(tree_id) * 47.0, 0)
	add_child(model)
	var bark := Figure.wood(Color(0.4, 0.27, 0.15))
	var bark_dark := Figure.wood(Color(0.26, 0.16, 0.09))
	var cut := Figure.wood(Color(0.64, 0.48, 0.28))
	if stump:
		Figure.add_mesh(model, Figure.cylinder(0.16, 0.28, 0.42, 10), Vector3(0, 0.21, 0), bark)
		Figure.add_mesh(model, Figure.cylinder(0.15, 0.15, 0.035, 10), Vector3(0, 0.43, 0), cut, Vector3.ZERO, false)
		return
	var lean := 5.0 if tree_id % 2 == 0 else -4.0
	Figure.add_mesh(model, Figure.cylinder(0.1, 0.24, 1.25, 10), Vector3(0, 0.62, 0), bark, Vector3(0, 0, lean))
	Figure.add_mesh(model, Figure.sphere(0.07, 0.09, 8), Vector3(0.12, 0.55, 0.06), bark_dark, Vector3.ZERO, false)
	Figure.span(model, Vector3(0.05, 0.2, 0), Vector3(0.5, 0.02, 0.18), 0.04, bark)
	Figure.span(model, Vector3(-0.02, 0.18, 0.02), Vector3(-0.42, 0.02, -0.16), 0.035, bark)
	var foliage: Array[Material] = [
		Figure.cloth(Color(0.34, 0.4, 0.22), 0.84),
		Figure.cloth(Color(0.25, 0.33, 0.16), 0.88),
		Figure.cloth(Color(0.48, 0.46, 0.26), 0.8),
	]
	var forks := [
		[Vector3(0.08, 1.15, 0.02), Vector3(1.15, 1.95, 0.4)],
		[Vector3(-0.06, 1.1, -0.02), Vector3(-1.2, 1.85, -0.25)],
		[Vector3(0.02, 1.22, -0.04), Vector3(0.3, 2.15, -1.05)],
		[Vector3(0.0, 1.18, 0.04), Vector3(-0.35, 2.05, 1.0)],
	]
	for i in forks.size():
		var pair: Array = forks[i]
		var base: Vector3 = pair[0]
		var tip: Vector3 = pair[1]
		Figure.span(model, base, tip, 0.04, bark)
		var pad := Figure.add_mesh(model, Figure.sphere(0.55, 0.7, 12), tip + Vector3(0, 0.08, 0), foliage[i % foliage.size()])
		pad.scale = Vector3(1.2, 0.32, 1.0)
		var twig: Vector3 = tip + (tip - base).normalized() * 0.4 + Vector3(0, 0.1, 0)
		var sprig := Figure.add_mesh(model, Figure.sphere(0.34, 0.42, 10), twig, foliage[(i + 1) % foliage.size()])
		sprig.scale = Vector3(1.05, 0.28, 0.85)


func _refresh() -> void:
	var sim := camp()
	var gone := sim != null and sim.chopped.has(tree_id)
	if gone == _cut:
		return
	_cut = gone
	_build(gone)


func prompt_for(_by: Node) -> String:
	if _cut:
		return "Already cut"
	return "Cut acacia"


func can_use(_by: Node) -> bool:
	return not _cut


func interact(_by: Node) -> bool:
	var sim := camp()
	if sim == null or _cut:
		return false
	return sim.chop_tree(tree_id)
