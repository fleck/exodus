class_name Figure
extends RefCounted
## Shared people and materials. Leaders, raiders, and the near camp
## are built from the same body so they read as the same crowd.

const SKIN_COLORS: Array[Color] = [
	Color(0.62, 0.44, 0.30),
	Color(0.50, 0.34, 0.23),
	Color(0.56, 0.39, 0.27),
	Color(0.42, 0.29, 0.20),
	Color(0.68, 0.50, 0.36),
	Color(0.36, 0.24, 0.17),
]
const ROBE_COLORS: Array[Color] = [
	Color(0.72, 0.58, 0.40),
	Color(0.46, 0.31, 0.20),
	Color(0.58, 0.27, 0.18),
	Color(0.32, 0.36, 0.42),
	Color(0.78, 0.72, 0.58),
	Color(0.36, 0.23, 0.16),
	Color(0.52, 0.40, 0.28),
	Color(0.25, 0.29, 0.27),
]
const GEMS: Array[Color] = [
	Color(0.72, 0.14, 0.16),
	Color(0.18, 0.42, 0.72),
	Color(0.16, 0.52, 0.28),
	Color(0.86, 0.7, 0.22),
	Color(0.52, 0.22, 0.55),
	Color(0.84, 0.46, 0.16),
	Color(0.2, 0.62, 0.58),
	Color(0.9, 0.88, 0.8),
	Color(0.42, 0.16, 0.14),
	Color(0.28, 0.36, 0.7),
	Color(0.62, 0.52, 0.2),
	Color(0.68, 0.28, 0.36),
]

static var _cache: Dictionary = {}
static var _distant: ArrayMesh


static func build(parent: Node3D, kind: StringName, robe_color: Color, trim_color: Color, skin_color: Color, variety: int = 0) -> Dictionary:
	var male := kind != &"Miriam"
	if kind == &"villager":
		male = variety % 2 == 0
	var broad := 1.0
	if kind == &"Joshua" or kind == &"amalekite":
		broad = 1.1
	elif kind == &"Miriam":
		broad = 0.92
	var hem_y := 0.08
	var show_legs := false
	var sleeved := true
	if kind == &"Joshua":
		hem_y = 0.52
		show_legs = true
		sleeved = false
	elif kind == &"amalekite":
		hem_y = 0.66
		show_legs = true
		sleeved = false
	elif kind == &"villager" and variety % 5 == 0:
		hem_y = 0.52
		show_legs = true
		sleeved = false

	var skin := skin(skin_color)
	var robe := cloth(robe_color)
	var robe_deep := cloth(robe_color.darkened(0.14))
	var trim := cloth(trim_color, 0.55, 0.15)
	var hide := leather(trim_color.darkened(0.05))
	var hair_color := _hair_color(kind, variety)
	var hair_mat := hair(hair_color)

	var body := Node3D.new()
	body.name = "Body"
	parent.add_child(body)

	var shoulder_x := 0.2 * broad + 0.05
	var hip_y := 0.98
	var shoulder_y := 1.34
	var head_y := 1.6

	# Torso and skirt. The cloth is the silhouette; skin shows at the neck, hands, and below a short hem.
	add_mesh(body, cylinder(0.23 * broad, 0.18 * broad, 0.44, 16), Vector3(0, 1.16, 0), robe)
	var skirt_top := 1.02
	var skirt_h := skirt_top - hem_y
	var flare := 0.46 if hem_y < 0.3 else 0.34
	add_mesh(body, cylinder(0.2 * broad, flare, skirt_h, 16), Vector3(0, hem_y + skirt_h * 0.5, 0), robe)
	add_mesh(body, cylinder(flare + 0.02, flare + 0.03, 0.06, 16), Vector3(0, hem_y + 0.05, 0), trim)
	add_mesh(body, cylinder(0.22 * broad, 0.22 * broad, 0.07, 14), Vector3(0, 1.0, 0), hide if show_legs else trim)
	add_mesh(body, sphere(0.09 * broad, 0.16, 12), Vector3(-shoulder_x, shoulder_y, 0), robe)
	add_mesh(body, sphere(0.09 * broad, 0.16, 12), Vector3(shoulder_x, shoulder_y, 0), robe)
	add_mesh(body, cylinder(0.055, 0.05, 0.16, 10), Vector3(0, 1.46, 0), skin)
	add_mesh(body, cylinder(0.09, 0.1, 0.06, 12), Vector3(0, 1.4, 0), robe_deep)

	if kind == &"Moses":
		add_mesh(body, box(Vector3(0.58, 0.72, 0.035)), Vector3(0, 1.02, -0.28), robe_deep)
	if kind == &"Aaron":
		add_mesh(body, cylinder(0.16, 0.34, 0.1, 14), Vector3(0, hem_y + 0.08, 0), cloth(Color(0.9, 0.88, 0.8)))
	if kind == &"Miriam":
		var sash := add_mesh(body, box(Vector3(0.1, 0.72, 0.04)), Vector3(0.02, 1.05, 0.24), trim)
		sash.rotation_degrees = Vector3(0, 0, 16)

	var arm_l := _limb(body, "ArmL", Vector3(shoulder_x, shoulder_y, 0.03), 0.16, 0.3, 0.26, 0.055 * broad, skin, robe if sleeved else null)
	var arm_r := _limb(body, "ArmR", Vector3(-shoulder_x, shoulder_y, 0.03), -0.16, 0.3, 0.26, 0.055 * broad, skin, robe if sleeved else null)
	_hand(arm_l["end"], skin)
	_hand(arm_r["end"], skin)

	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	var feet: Array[Node3D] = []
	if show_legs:
		var leg_l := _limb(body, "LegL", Vector3(0.1, hip_y, 0), 0.0, 0.46, 0.44, 0.075, skin, null, false)
		var leg_r := _limb(body, "LegR", Vector3(-0.1, hip_y, 0), 0.0, 0.46, 0.44, 0.075, skin, null, false)
		feet.append(_foot(leg_l["end"], hide))
		feet.append(_foot(leg_r["end"], hide))
		legs.append(leg_l["pivot"] as Node3D)
		legs.append(leg_r["pivot"] as Node3D)
		knees.append(leg_l["joint"] as Node3D)
		knees.append(leg_r["joint"] as Node3D)
		if kind == &"Joshua":
			add_mesh(leg_l["joint"], cylinder(0.07, 0.065, 0.16, 8), Vector3(0, -0.12, 0), hide, Vector3.ZERO, false)
			add_mesh(leg_r["joint"], cylinder(0.07, 0.065, 0.16, 8), Vector3(0, -0.12, 0), hide, Vector3.ZERO, false)
	else:
		add_mesh(body, box(Vector3(0.1, 0.03, 0.18)), Vector3(0.09, 0.035, 0.05), hide, Vector3.ZERO, false)
		add_mesh(body, box(Vector3(0.1, 0.03, 0.18)), Vector3(-0.09, 0.035, 0.05), hide, Vector3.ZERO, false)

	if not sleeved and (kind == &"Joshua" or kind == &"amalekite"):
		add_mesh(arm_l["joint"], cylinder(0.062, 0.058, 0.12, 8), Vector3(0, -0.08, 0), hide, Vector3.ZERO, false)
		add_mesh(arm_r["joint"], cylinder(0.062, 0.058, 0.12, 8), Vector3(0, -0.08, 0), hide, Vector3.ZERO, false)

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, head_y, 0)
	body.add_child(head)
	_head(head, kind, variety, male, skin, skin_color, hair_mat, hair_color, robe, robe_color, trim, trim_color)

	_gear(body, kind, trim, trim_color, hide, arm_l["end"], arm_r["end"])

	return {
		"root": parent,
		"body": body,
		"head": head,
		"arms": [arm_l["pivot"], arm_r["pivot"]],
		"elbows": [arm_l["joint"], arm_r["joint"]],
		"arm_out": [0.16, -0.16],
		"legs": legs,
		"knees": knees,
		"feet": feet,
		"show_legs": show_legs,
		"hand_l": arm_l["end"],
		"hand_r": arm_r["end"],
	}


static func pose(rig: Dictionary, time_sec: float, speed: float, action: String) -> void:
	if rig.is_empty():
		return
	var pace := clampf(speed, 0.0, 1.6)
	var rate := lerpf(1.4, 8.0, pace / 1.5)
	var phase := time_sec * rate
	var swing := sin(phase)
	var arm_amp := 0.045 + pace * 0.5
	var leg_amp := pace * 0.4
	var arms: Array = rig["arms"]
	var elbows: Array = rig["elbows"]
	var out: Array = rig["arm_out"]
	var body: Node3D = rig["body"]
	var head: Node3D = rig["head"]
	var show_legs: bool = rig["show_legs"]
	var legs: Array = rig["legs"]
	var knees: Array = rig["knees"]
	var feet: Array = rig["feet"]

	body.rotation = Vector3(0.05 * pace, 0.0, swing * 0.03 * pace)
	head.rotation = Vector3(sin(phase * 2.0) * 0.025 * pace, 0.0, 0.0)
	arms[0].rotation = Vector3(-swing * arm_amp, 0.0, float(out[0]))
	arms[1].rotation = Vector3(swing * arm_amp, 0.0, float(out[1]))
	elbows[0].rotation = Vector3(-0.42 - maxf(swing, 0.0) * 0.28 * maxf(pace, 0.25), 0.0, 0.0)
	elbows[1].rotation = Vector3(-0.42 - maxf(-swing, 0.0) * 0.28 * maxf(pace, 0.25), 0.0, 0.0)

	if show_legs:
		legs[0].rotation = Vector3(swing * leg_amp, 0.0, 0.0)
		legs[1].rotation = Vector3(-swing * leg_amp, 0.0, 0.0)
		knees[0].rotation = Vector3(maxf(-swing, 0.0) * leg_amp * 1.3, 0.0, 0.0)
		knees[1].rotation = Vector3(maxf(swing, 0.0) * leg_amp * 1.3, 0.0, 0.0)

	match action:
		"channel":
			body.rotation = Vector3(-0.06, 0.0, 0.0)
			head.rotation = Vector3(-0.12, 0.0, 0.0)
			arms[0].rotation = Vector3(-2.45, 0.15, 0.38)
			arms[1].rotation = Vector3(-2.45, -0.15, -0.38)
			elbows[0].rotation = Vector3(-0.22, 0.0, 0.0)
			elbows[1].rotation = Vector3(-0.22, 0.0, 0.0)
		"offer":
			body.rotation = Vector3(-0.04, 0.0, 0.0)
			arms[0].rotation = Vector3(-1.65, 0.2, 0.42)
			arms[1].rotation = Vector3(-1.65, -0.2, -0.42)
			elbows[0].rotation = Vector3(-0.75, 0.0, 0.0)
			elbows[1].rotation = Vector3(-0.75, 0.0, 0.0)
		"brace":
			arms[0].rotation = Vector3(-1.15, 0.3, 0.72)
			arms[1].rotation = Vector3(-1.15, -0.3, -0.72)
			elbows[0].rotation = Vector3(-1.0, 0.0, 0.0)
			elbows[1].rotation = Vector3(-1.0, 0.0, 0.0)
		"strike":
			body.rotation = Vector3(0.1, 0.0, 0.0)
			arms[1].rotation = Vector3(-1.4, -0.1, float(out[1]) * 0.3)
			arms[0].rotation = Vector3(-0.45, 0.15, float(out[0]))
			elbows[1].rotation = Vector3(-0.18, 0.0, 0.0)
			elbows[0].rotation = Vector3(-0.85, 0.0, 0.0)
			if show_legs:
				legs[1].rotation = Vector3(-0.28, 0.0, 0.0)
				legs[0].rotation = Vector3(0.18, 0.0, 0.0)
				knees[0].rotation = Vector3.ZERO
				knees[1].rotation = Vector3(0.35, 0.0, 0.0)
		"stagger":
			body.rotation = Vector3(0.32, 0.0, 0.0)
			head.rotation = Vector3(0.2, 0.0, 0.0)
			arms[0].rotation = Vector3(0.55, 0.0, 0.7)
			arms[1].rotation = Vector3(0.4, 0.0, -0.65)
			elbows[0].rotation = Vector3(-0.3, 0.0, 0.0)
			elbows[1].rotation = Vector3(-0.3, 0.0, 0.0)

	if show_legs:
		for i in 2:
			var foot: Node3D = feet[i]
			var leg: Node3D = legs[i]
			var knee: Node3D = knees[i]
			foot.rotation = Vector3(-(leg.rotation.x + knee.rotation.x), 0.0, 0.0)

	var root: Node3D = rig["root"]
	var bob := (1.0 - absf(sin(phase))) * (0.04 if pace > 0.2 else 0.008)
	if action == "stagger":
		bob = 0.0
	root.position.y = bob


static func distant_mesh() -> ArrayMesh:
	if _distant != null:
		return _distant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var robe := Color(0.62, 0.46, 0.3, 1)
	var hide := Color(0.38, 0.24, 0.14, 1)
	var skin_c := Color(0.55, 0.38, 0.26, 0)
	var hair_c := Color(0.16, 0.1, 0.07, 0)
	var linen := Color(0.86, 0.82, 0.72, 0)
	_bake(st, cylinder(0.22, 0.18, 0.42, 10), Transform3D(Basis.IDENTITY, Vector3(0, 1.16, 0)), robe)
	_bake(st, cylinder(0.2, 0.4, 0.9, 10), Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0)), robe)
	_bake(st, cylinder(0.42, 0.44, 0.05, 10), Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), hide)
	_bake(st, sphere(0.12, 0.24, 12), Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)), skin_c)
	_bake(st, sphere(0.125, 0.2, 10), Transform3D(Basis.IDENTITY.scaled(Vector3(1.05, 0.55, 1.05)), Vector3(0, 1.68, -0.02)), linen)
	_bake(st, capsule(0.05, 0.48), Transform3D(Basis.IDENTITY, Vector3(0.28, 1.05, 0.04)), robe)
	_bake(st, capsule(0.05, 0.48), Transform3D(Basis.IDENTITY, Vector3(-0.28, 1.05, 0.04)), robe)
	_bake(st, sphere(0.045, 0.08, 8), Transform3D(Basis.IDENTITY, Vector3(0.3, 0.78, 0.06)), skin_c)
	_bake(st, sphere(0.045, 0.08, 8), Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.78, 0.06)), skin_c)
	_bake(st, sphere(0.06, 0.1, 8), Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0.06)), hair_c)
	_distant = st.commit()
	var fallback := StandardMaterial3D.new()
	fallback.vertex_color_use_as_albedo = true
	fallback.roughness = 0.86
	_distant.surface_set_material(0, fallback)
	return _distant


static func held_up(side: float) -> Basis:
	# side is -1 for the person's right hand and +1 for the left.
	return basis_y(Vector3(0.18 * side, 0.9, 0.4))


static func held_offset(side: float) -> Vector3:
	return Vector3(0.06 * side, 0.28, 0.14)


static func basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	if y.length_squared() < 0.001:
		return Basis.IDENTITY
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func span(parent: Node, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var dir := b - a
	var length := maxf(dir.length(), 0.001)
	var node := add_mesh(parent, cylinder(radius, radius, length, 6), (a + b) * 0.5, material)
	node.basis = basis_y(dir)
	return node


static func add_mesh(parent: Node, mesh: Mesh, at: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rot_deg
	node.material_override = material
	if not shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func sphere(radius: float, height: float = -1.0, seg: int = 16) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	mesh.radial_segments = seg
	mesh.rings = maxi(6, int(seg / 2))
	return mesh


static func capsule(radius: float, length: float, seg: int = 12) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0 + 0.002)
	mesh.radial_segments = seg
	mesh.rings = 3
	return mesh


static func cylinder(radius_top: float, radius_bottom: float, height: float, seg: int = 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_top
	mesh.bottom_radius = radius_bottom
	mesh.height = maxf(height, 0.001)
	mesh.radial_segments = seg
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func skin(color: Color) -> StandardMaterial3D:
	var key := "skin|%s" % color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.56
	material.metallic = 0.0
	material.metallic_specular = 0.28
	material.rim_enabled = true
	material.rim = 0.18
	material.rim_tint = 0.62
	_cache[key] = material
	return material


static func cloth(color: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	return _simple("cloth|%s|%.2f|%.2f" % [color.to_html(false), rough, metal], color, rough, metal)


static func hair(color: Color) -> StandardMaterial3D:
	return _simple("hair|%s" % color.to_html(false), color, 0.58, 0.02)


static func leather(color: Color) -> StandardMaterial3D:
	return _simple("leather|%s" % color.to_html(false), color, 0.62, 0.08)


static func wood(color: Color) -> StandardMaterial3D:
	return _simple("wood|%s" % color.to_html(false), color, 0.88, 0.0)


static func stone(color: Color) -> StandardMaterial3D:
	return _simple("stone|%s" % color.to_html(false), color, 0.94, 0.0)


static func metal(color: Color, rough: float = 0.34, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := "metal|%s|%.2f|%.2f" % [color.to_html(false), rough, emission_energy]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = 0.92
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	_cache[key] = material
	return material


static func gem(color: Color) -> StandardMaterial3D:
	var key := "gem|%s" % color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.16
	material.metallic = 0.35
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.16
	_cache[key] = material
	return material


static func glow(color: Color, energy: float, rough: float = 0.45) -> StandardMaterial3D:
	var key := "glow|%s|%.2f|%.2f" % [color.to_html(false), energy, rough]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_cache[key] = material
	return material


static func _simple(key: String, color: Color, rough: float, metal_amount: float) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal_amount
	_cache[key] = material
	return material


static func _hair_color(kind: StringName, variety: int) -> Color:
	match kind:
		&"Moses":
			return Color(0.78, 0.76, 0.7)
		&"Aaron":
			return Color(0.28, 0.18, 0.12)
		&"Joshua":
			return Color(0.1, 0.07, 0.05)
		&"Miriam":
			return Color(0.07, 0.045, 0.03)
		&"amalekite":
			return Color(0.14, 0.08, 0.05)
		_:
			var palette: Array[Color] = [
				Color(0.12, 0.08, 0.05),
				Color(0.24, 0.15, 0.09),
				Color(0.4, 0.26, 0.14),
				Color(0.08, 0.06, 0.045),
				Color(0.5, 0.38, 0.24),
			]
			return palette[variety % palette.size()]


static func _limb(body: Node3D, limb_name: String, origin: Vector3, out_z: float, upper_len: float, lower_len: float, radius: float, skin_mat: Material, sleeve: Material, is_arm: bool = true) -> Dictionary:
	var pivot := Node3D.new()
	pivot.name = limb_name
	pivot.position = origin
	pivot.rotation.z = out_z
	body.add_child(pivot)
	var upper_mat: Material = sleeve if sleeve != null else skin_mat
	add_mesh(pivot, capsule(radius, upper_len), Vector3(0, -upper_len * 0.5, 0), upper_mat)
	var joint := Node3D.new()
	joint.name = "Joint"
	joint.position = Vector3(0, -upper_len, 0)
	if is_arm:
		joint.rotation.x = -0.42
	pivot.add_child(joint)
	var lower_mat: Material = sleeve if sleeve != null else skin_mat
	add_mesh(joint, capsule(radius * 0.86, lower_len), Vector3(0, -lower_len * 0.5, 0), lower_mat)
	var end := Node3D.new()
	end.name = "End"
	end.position = Vector3(0, -lower_len, 0)
	joint.add_child(end)
	return {"pivot": pivot, "joint": joint, "end": end}


static func _hand(end: Node3D, skin_mat: Material) -> void:
	var palm := add_mesh(end, sphere(0.042, 0.07, 10), Vector3(0, -0.02, 0.03), skin_mat, Vector3.ZERO, false)
	palm.scale = Vector3(0.85, 1.05, 0.7)


static func _foot(end: Node3D, hide: Material) -> Node3D:
	var foot := Node3D.new()
	foot.name = "Foot"
	end.add_child(foot)
	add_mesh(foot, box(Vector3(0.09, 0.035, 0.2)), Vector3(0, -0.045, 0.05), hide, Vector3.ZERO, false)
	add_mesh(foot, box(Vector3(0.09, 0.02, 0.025)), Vector3(0, -0.02, 0.02), hide, Vector3.ZERO, false)
	add_mesh(foot, box(Vector3(0.09, 0.02, 0.025)), Vector3(0, -0.02, 0.09), hide, Vector3.ZERO, false)
	return foot


static func _head(head: Node3D, kind: StringName, variety: int, male: bool, skin_mat: Material, skin_color: Color, hair_mat: Material, hair_color: Color, robe: Material, robe_color: Color, trim: Material, trim_color: Color) -> void:
	add_mesh(head, sphere(0.112, 0.23, 24), Vector3.ZERO, skin_mat)
	var jaw := add_mesh(head, sphere(0.086, 0.15, 16), Vector3(0, -0.05, 0.02), skin_mat)
	jaw.scale = Vector3(0.92, 0.78, 1.02)
	add_mesh(head, sphere(0.03, 0.055, 8), Vector3(-0.112, -0.01, 0.0), skin_mat, Vector3.ZERO, false).scale = Vector3(0.45, 0.85, 0.55)
	add_mesh(head, sphere(0.03, 0.055, 8), Vector3(0.112, -0.01, 0.0), skin_mat, Vector3.ZERO, false).scale = Vector3(0.45, 0.85, 0.55)
	if male:
		add_mesh(head, box(Vector3(0.1, 0.022, 0.04)), Vector3(0, 0.04, 0.095), skin_mat, Vector3.ZERO, false)
	_eyes(head, skin_color)
	add_mesh(head, sphere(0.026, 0.05, 8), Vector3(0, -0.005, 0.112), skin_mat, Vector3.ZERO, false).scale = Vector3(0.75, 0.85, 1.15)
	var lip := Color(minf(skin_color.r * 0.75 + 0.18, 1.0), skin_color.g * 0.48, skin_color.b * 0.42)
	add_mesh(head, box(Vector3(0.045, 0.012, 0.02)), Vector3(0, -0.055, 0.1), cloth(lip, 0.5), Vector3.ZERO, false)

	var cap := add_mesh(head, sphere(0.125, 0.22, 16), Vector3(0, 0.055, -0.04), hair_mat)
	cap.scale = Vector3(1.04, 0.68, 0.9)
	if kind == &"Miriam" or not male:
		add_mesh(head, capsule(0.045, 0.62, 8), Vector3(0.06, -0.28, -0.04), hair_mat, Vector3(8, 0, 6), false)
		add_mesh(head, capsule(0.045, 0.62, 8), Vector3(-0.06, -0.28, -0.04), hair_mat, Vector3(8, 0, -6), false)
	if male and kind != &"Miriam":
		var beard_len := 0.16
		if kind == &"Moses":
			beard_len = 0.38
		elif kind == &"Aaron":
			beard_len = 0.26
		elif kind == &"villager":
			beard_len = 0.2 if variety % 3 != 2 else 0.1
		_beard(head, beard_len, hair_mat)

	match kind:
		&"Moses":
			_keffiyeh(head, cloth(robe_color.lightened(0.04)), leather(Color(0.28, 0.16, 0.08)))
		&"Aaron":
			_turban(head, cloth(Color(0.92, 0.9, 0.84)), metal(trim_color, 0.3))
		&"Joshua":
			add_mesh(head, box(Vector3(0.16, 0.035, 0.05)), Vector3(0, 0.055, 0.09), leather(trim_color), Vector3.ZERO, false)
		&"Miriam":
			var veil := cloth(robe_color.lightened(0.22))
			add_mesh(head, box(Vector3(0.22, 0.04, 0.06)), Vector3(0, 0.07, 0.06), veil, Vector3.ZERO, false)
			add_mesh(head, box(Vector3(0.2, 0.7, 0.025)), Vector3(0, -0.22, -0.1), veil, Vector3.ZERO, false)
			add_mesh(head, sphere(0.012, 0.02, 6), Vector3(-0.1, -0.02, 0.04), metal(trim_color, 0.25), Vector3.ZERO, false)
			add_mesh(head, sphere(0.012, 0.02, 6), Vector3(0.1, -0.02, 0.04), metal(trim_color, 0.25), Vector3.ZERO, false)
		&"amalekite":
			_helmet(head, metal(Color(0.62, 0.48, 0.28), 0.38))
		_:
			if male and variety % 3 != 1:
				_keffiyeh(head, cloth(robe_color.lightened(0.08)), trim)
			elif not male:
				add_mesh(head, box(Vector3(0.2, 0.45, 0.02)), Vector3(0, -0.08, -0.11), cloth(robe_color.lightened(0.12)), Vector3.ZERO, false)


static func _eyes(head: Node3D, skin_color: Color) -> void:
	var sclera := cloth(Color(0.9, 0.86, 0.8), 0.4)
	var iris := hair(Color(0.12, 0.07, 0.045).lerp(skin_color, 0.15))
	for side in [-1.0, 1.0]:
		add_mesh(head, sphere(0.02, 0.034, 8), Vector3(0.04 * side, 0.02, 0.09), sclera, Vector3.ZERO, false)
		add_mesh(head, sphere(0.011, 0.02, 6), Vector3(0.04 * side, 0.02, 0.108), iris, Vector3.ZERO, false)
		var brow := hair(Color(0.1, 0.07, 0.05))
		add_mesh(head, box(Vector3(0.04, 0.012, 0.015)), Vector3(0.042 * side, 0.05, 0.1), brow, Vector3(0, 12 * side, 8 * side), false)


static func _beard(head: Node3D, length: float, hair_mat: Material) -> void:
	add_mesh(head, sphere(0.03, 0.04, 8), Vector3(0, -0.07, 0.07), hair_mat, Vector3.ZERO, false).scale = Vector3(1.6, 0.55, 0.7)
	add_mesh(head, sphere(0.055, 0.09, 10), Vector3(0, -0.09, 0.04), hair_mat, Vector3.ZERO, false)
	if length > 0.18:
		add_mesh(head, capsule(0.055, length, 8), Vector3(0, -0.12 - length * 0.35, 0.03), hair_mat, Vector3.ZERO, false)


static func _keffiyeh(head: Node3D, linen: Material, cord: Material) -> void:
	var crown := add_mesh(head, sphere(0.13, 0.18, 14), Vector3(0, 0.09, -0.045), linen, Vector3.ZERO, false)
	crown.scale = Vector3(1.15, 0.38, 0.82)
	add_mesh(head, box(Vector3(0.035, 0.32, 0.07)), Vector3(-0.11, -0.06, 0.02), linen, Vector3.ZERO, false)
	add_mesh(head, box(Vector3(0.035, 0.32, 0.07)), Vector3(0.11, -0.06, 0.02), linen, Vector3.ZERO, false)
	add_mesh(head, box(Vector3(0.18, 0.36, 0.025)), Vector3(0, -0.1, -0.11), linen, Vector3.ZERO, false)
	var agal := add_mesh(head, TorusMesh.new(), Vector3(0, 0.07, -0.01), cord, Vector3.ZERO, false)
	var torus := agal.mesh as TorusMesh
	torus.inner_radius = 0.09
	torus.outer_radius = 0.115
	torus.rings = 8
	torus.ring_segments = 10
	agal.scale = Vector3(1, 0.35, 1)


static func _turban(head: Node3D, linen: Material, band: Material) -> void:
	add_mesh(head, cylinder(0.11, 0.125, 0.14, 14), Vector3(0, 0.2, 0), linen, Vector3.ZERO, false)
	add_mesh(head, cylinder(0.13, 0.13, 0.035, 14), Vector3(0, 0.125, 0), linen, Vector3.ZERO, false)
	add_mesh(head, cylinder(0.135, 0.135, 0.02, 14), Vector3(0, 0.145, 0), band, Vector3.ZERO, false)
	add_mesh(head, box(Vector3(0.08, 0.28, 0.025)), Vector3(0.02, -0.02, -0.12), linen, Vector3.ZERO, false)


static func _helmet(head: Node3D, bronze: Material) -> void:
	var dome := sphere(0.13, 0.2, 16)
	dome.is_hemisphere = true
	add_mesh(head, dome, Vector3(0, 0.08, -0.01), bronze, Vector3.ZERO, false)
	add_mesh(head, cylinder(0.125, 0.13, 0.028, 14), Vector3(0, 0.075, -0.01), bronze, Vector3.ZERO, false)
	add_mesh(head, box(Vector3(0.02, 0.09, 0.05)), Vector3(-0.09, -0.02, 0.04), bronze, Vector3.ZERO, false)
	add_mesh(head, box(Vector3(0.02, 0.09, 0.05)), Vector3(0.09, -0.02, 0.04), bronze, Vector3.ZERO, false)
	add_mesh(head, box(Vector3(0.02, 0.07, 0.025)), Vector3(0, 0.0, 0.12), bronze, Vector3.ZERO, false)


static func _gear(body: Node3D, kind: StringName, _trim: Material, trim_color: Color, hide: Material, hand_l: Node3D, hand_r: Node3D) -> void:
	if kind == &"Aaron":
		var gold := metal(trim_color, 0.28, 0.08)
		var linen := cloth(Color(0.9, 0.88, 0.82))
		add_mesh(body, box(Vector3(0.36, 0.4, 0.04)), Vector3(0, 1.16, 0.22), linen)
		add_mesh(body, box(Vector3(0.3, 0.34, 0.05)), Vector3(0, 1.16, 0.26), gold)
		add_mesh(body, box(Vector3(0.06, 0.28, 0.04)), Vector3(-0.14, 1.32, 0.16), gold, Vector3(0, 0, 18), false)
		add_mesh(body, box(Vector3(0.06, 0.28, 0.04)), Vector3(0.14, 1.32, 0.16), gold, Vector3(0, 0, -18), false)
		for row in 3:
			for col in 4:
				var gem_color: Color = GEMS[row * 4 + col]
				add_mesh(body, sphere(0.022, 0.04, 8), Vector3(-0.09 + float(col) * 0.06, 1.26 - float(row) * 0.09, 0.3), gem(gem_color), Vector3.ZERO, false)
	elif kind == &"Joshua":
		add_mesh(body, box(Vector3(0.34, 0.32, 0.08)), Vector3(0, 1.18, 0.24), hide)
		add_mesh(body, box(Vector3(0.08, 0.55, 0.03)), Vector3(0.1, 1.12, 0.28), leather(trim_color.lightened(0.05)), Vector3(0, 0, 22), false)
	elif kind == &"amalekite":
		var shaft_wood := wood(Color(0.4, 0.26, 0.14))
		var bronze := metal(Color(0.66, 0.5, 0.28), 0.36)
		var shield := add_mesh(hand_l, cylinder(0.2, 0.2, 0.03, 14), Vector3(0.02, 0.1, 0.08), shaft_wood, Vector3(78, 0, 0), false)
		add_mesh(shield, cylinder(0.21, 0.21, 0.018, 14), Vector3(0, 0.02, 0), bronze, Vector3.ZERO, false)
		add_mesh(shield, sphere(0.04, 0.06, 8), Vector3(0, 0.04, 0), bronze, Vector3.ZERO, false)
		var shaft := add_mesh(hand_r, cylinder(0.016, 0.02, 1.85, 8), held_offset(-1.0), shaft_wood)
		shaft.basis = held_up(-1.0)
		add_mesh(shaft, cylinder(0.0, 0.045, 0.26, 8), Vector3(0, 0.98, 0), bronze, Vector3.ZERO, false)


static func _bake(st: SurfaceTool, mesh: Mesh, xf: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms := PackedVector3Array()
	if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		norms = arrays[Mesh.ARRAY_NORMAL]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xf.basis.inverse().transposed()
	var count := indices.size() if not indices.is_empty() else verts.size()
	for n in count:
		var idx: int = indices[n] if not indices.is_empty() else n
		st.set_color(color)
		var normal := Vector3.UP if norms.is_empty() else norms[idx]
		st.set_normal((normal_basis * normal).normalized())
		st.add_vertex(xf * verts[idx])
