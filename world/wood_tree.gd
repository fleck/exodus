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
	for child in get_children():
		child.queue_free()
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12 if stump else 0.18
	cyl.bottom_radius = 0.28
	cyl.height = 0.4 if stump else 2.2
	trunk.mesh = cyl
	trunk.position.y = cyl.height * 0.5
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.38, 0.26, 0.16)
	bark.roughness = 0.9
	trunk.material_override = bark
	add_child(trunk)
	if stump:
		return
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.1
	sphere.height = 1.6
	crown.mesh = sphere
	crown.position.y = 2.5
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.28, 0.38, 0.2)
	leaf.roughness = 0.85
	crown.material_override = leaf
	add_child(crown)


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
