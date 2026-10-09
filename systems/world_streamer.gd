class_name WorldStreamer
extends Node3D
## Sinai chunks around the leaders. Gameplay stays on the flat center.
## A Terrain3D region can replace `_build_mesh` later; the chunk keys stay.

const CHUNK_SIZE := 256.0
const RESOLUTION := 14

var _noise := FastNoiseLite.new()
var _loaded: Dictionary = {}
var _material: ShaderMaterial
var _timer := 0.0


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = 40
	_noise.frequency = 1.0
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/shaders/sand.gdshader")
	_refresh()
	_add_haze()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.45:
		return
	_timer = 0.0
	_refresh()


func sample_height(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	var mask := smoothstep(190.0, 320.0, dist)
	var broad := _noise.get_noise_2d(x * 0.004, z * 0.004)
	var fine := _noise.get_noise_2d(x * 0.02 + 40.0, z * 0.02)
	return (broad * 16.0 + fine * 2.2) * mask


func _refresh() -> void:
	var needed := {}
	var anchors: Array[Vector3] = [Vector3.ZERO]
	for node in get_tree().get_nodes_in_group("leaders"):
		if node is Node3D:
			anchors.append((node as Node3D).global_position)
	for anchor in anchors:
		var cx := int(floor(anchor.x / CHUNK_SIZE))
		var cz := int(floor(anchor.z / CHUNK_SIZE))
		for x in range(cx - 1, cx + 2):
			for z in range(cz - 1, cz + 2):
				needed[Vector2i(x, z)] = true
	for key in needed:
		if not _loaded.has(key):
			_loaded[key] = _make_chunk(key)
	var stale: Array = []
	for key in _loaded:
		if not needed.has(key):
			stale.append(key)
	for key in stale:
		var node: Node = _loaded[key]
		node.queue_free()
		_loaded.erase(key)


func _make_chunk(key: Vector2i) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _build_mesh(key)
	mesh_node.material_override = _material
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_node)
	return mesh_node


func _build_mesh(key: Vector2i) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := Vector3(float(key.x) * CHUNK_SIZE, 0, float(key.y) * CHUNK_SIZE)
	var step := CHUNK_SIZE / float(RESOLUTION)
	for z in RESOLUTION:
		for x in RESOLUTION:
			var x0 := origin.x + float(x) * step
			var z0 := origin.z + float(z) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var p00 := Vector3(x0, sample_height(x0, z0), z0)
			var p10 := Vector3(x1, sample_height(x1, z0), z0)
			var p01 := Vector3(x0, sample_height(x0, z1), z1)
			var p11 := Vector3(x1, sample_height(x1, z1), z1)
			_tri(st, p00, p10, p11)
			_tri(st, p00, p11, p01)
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x, a.z) * 0.02)
	st.add_vertex(a)
	st.set_uv(Vector2(b.x, b.z) * 0.02)
	st.add_vertex(b)
	st.set_uv(Vector2(c.x, c.z) * 0.02)
	st.add_vertex(c)


func _add_haze() -> void:
	var haze := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 150.0
	cyl.bottom_radius = 170.0
	cyl.height = 28.0
	haze.mesh = cyl
	haze.position.y = 10.0
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/heat_haze.gdshader")
	haze.material_override = mat
	add_child(haze)
