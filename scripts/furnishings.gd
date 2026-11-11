extends Node3D
## Human-scale timber ship fittings. Ground-relative origins; fronts face -Z.
## bed 1.1×2.1, chair .48×.55, shelf 1.1×.36, locker .68×.50,
## barrel Ø.66, stove .75×.65, desk 1.2×.60. Lantern origin is its centre.

const Geometry = preload("res://scripts/geometry.gd")
var materials: Dictionary = {}

func configure(palette: Dictionary) -> void:
	materials = palette.duplicate()
	var defaults := {"wood": "58402a", "wood_dark": "30251b", "wood_light": "816447", "iron": "292d29", "brass": "8e7042", "copper": "805239", "cloth": "675f4a", "canvas": "a3926e", "leather": "443228", "paper": "c8b68c", "ceramic": "b4b19a", "rope": "8d7958", "dark": "191a16", "glow_amber": "dfa25b"}
	for key in defaults:
		if materials.has(key):
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(defaults[key])
		mat.roughness = 0.9
		mat.metallic = 0.25 if key in ["iron", "brass", "copper"] else 0.0
		if key == "glow_amber":
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 0.9
		materials[key] = mat

func _group(parent: Node3D, pos: Vector3, title: String, yaw: float = 0.0) -> Node3D:
	if materials.is_empty():
		configure({})
	var item := Node3D.new()
	item.name = title
	parent.add_child(item)
	item.position = pos
	item.rotation.y = yaw
	return item

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: String, detail: bool = false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = materials.get(material, materials["wood"])
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if detail else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(item)
	item.position = pos
	return item

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: String, detail: bool = false) -> MeshInstance3D:
	return _mesh(parent, Geometry.beveled_box(size, minf(0.018, minf(size.x, minf(size.y, size.z)) * 0.18)), pos, material, detail)

func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, material: String, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.height = height
	mesh.radial_segments = 24 if radius > 0.1 else 12
	return _mesh(parent, mesh, pos, material)

func _pipe(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: String) -> MeshInstance3D:
	var item := _cyl(parent, (a + b) * 0.5, radius, a.distance_to(b), material)
	item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return item

func _ring(parent: Node3D, pos: Vector3, radius: float, tube: float, material: String, vertical: bool = false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 24
	mesh.ring_segments = 8
	var item := _mesh(parent, mesh, pos, material, true)
	if vertical:
		item.rotation.x = PI / 2.0
	return item

func _collision(parent: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(body)
	body.add_child(collision)
	collision.position = offset + Vector3.UP * size.y * 0.5

func _text(parent: Node3D, pos: Vector3, text: String, scale_value: float = 0.0018) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 30
	label.pixel_size = scale_value
	label.modulate = Color("c4ad7b")
	label.shaded = true
	label.outline_size = 0
	parent.add_child(label)
	label.position = pos
	label.rotation.y = PI
	return label

func _curtain(parent: Node3D, pos: Vector3, width: float, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var x0: float = float(i) / 16.0
		var x1: float = float(i + 1) / 16.0
		var a := Vector3(x0 * width, 0, sin(x0 * TAU * 3) * 0.025)
		var b := Vector3(x1 * width, 0, sin(x1 * TAU * 3) * 0.025)
		var c := b + Vector3.DOWN * (height - sin(x1 * PI) * 0.015)
		var d := a + Vector3.DOWN * (height - sin(x0 * PI) * 0.015)
		for vertex in [a, c, b, a, d, c, a, b, c, a, c, d]:
			surface.set_uv(Vector2(vertex.x / width, -vertex.y / height))
			surface.add_vertex(vertex)
	surface.generate_normals()
	_mesh(parent, surface.commit(), pos, "cloth")

func bed(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var item := _group(parent, pos, "TimberBunkBerths", yaw)
	for x in [-0.51, 0.51]:
		for z in [-1.0, 1.0]:
			_box(item, Vector3(x, 1.17, z), Vector3(0.08, 2.34, 0.08), "wood_dark")
			_cyl(item, Vector3(x, 2.36, z), 0.055, 0.045, "brass")
	for level in [0.39, 1.52]:
		_box(item, Vector3(0, level, 0), Vector3(1.05, 0.12, 2.05), "wood_dark")
		_box(item, Vector3(0, level + 0.12, 0), Vector3(0.94, 0.17, 1.91), "canvas")
		_box(item, Vector3(0, level + 0.235, -0.26), Vector3(0.96, 0.065, 1.35), "cloth")
		_box(item, Vector3(0.46, level + 0.11, -0.26), Vector3(0.055, 0.24, 1.35), "cloth")
		_box(item, Vector3(-0.02, level + 0.26, 0.68), Vector3(0.69, 0.13, 0.37), "canvas")
		for z in [-0.91, -0.79]:
			_box(item, Vector3(0, level + 0.274, z), Vector3(0.96, 0.009, 0.016), "canvas", true)
		for z in [-0.98, 0.98]:
			_box(item, Vector3(0, level + 0.27, z), Vector3(1.02, 0.38, 0.055), "wood")
			_box(item, Vector3(0, level + 0.47, z), Vector3(1.08, 0.055, 0.08), "wood_light")
		_pipe(item, Vector3(-0.51, level + 0.75, -1.02), Vector3(0.51, level + 0.75, -1.02), 0.014, "brass")
		_curtain(item, Vector3(-0.5, level + 0.72, -1.04), 0.23, 0.64)
		_curtain(item, Vector3(0.27, level + 0.72, -1.04), 0.23, 0.64)
	# Narrow side ladder; the berths themselves remain decorative furniture.
	for z in [-0.77, -0.41]:
		_box(item, Vector3(0.545, 0.85, z), Vector3(0.04, 1.7, 0.055), "wood_light")
	for y in [0.25, 0.55, 0.85, 1.15, 1.45]:
		_box(item, Vector3(0.555, y, -0.59), Vector3(0.07, 0.045, 0.4), "wood")
	_box(item, Vector3(0, 0.17, -0.6), Vector3(0.78, 0.26, 0.72), "wood")
	_box(item, Vector3(0, 0.17, -0.975), Vector3(0.11, 0.055, 0.025), "brass")
	_collision(item, Vector3(1.14, 2.4, 2.1))
	return item

func table(parent: Node3D, pos: Vector3, size: Vector2 = Vector2(2.2, 1.2), yaw: float = 0.0, dressed: bool = true) -> Node3D:
	var item := _group(parent, pos, "MessTrestleTable", yaw)
	var planks: int = maxi(3, roundi(size.y / 0.15))
	for i in range(planks):
		var z: float = -size.y * 0.5 + (i + 0.5) * size.y / planks
		_box(item, Vector3(0, 0.735, z), Vector3(size.x, 0.075, size.y / planks - 0.006), "wood_light" if i % 3 == 0 else "wood")
	for x in [-size.x * 0.34, size.x * 0.34]:
		_box(item, Vector3(x, 0.38, 0), Vector3(0.17, 0.7, size.y * 0.55), "wood_dark")
		_box(item, Vector3(x, 0.09, 0), Vector3(0.24, 0.16, size.y * 0.87), "wood_dark")
	_box(item, Vector3(0, 0.29, 0), Vector3(size.x * 0.79, 0.12, 0.13), "wood_dark")
	if dressed:
		if size.y > size.x * 1.3:
			for z in [-size.y * 0.38, 0.0, size.y * 0.38]:
				for side in [-1.0, 1.0]:
					var at := Vector3(side * (size.x * 0.5 - 0.22), 0.79, z)
					_plate(item, at)
					_mug(item, at + Vector3(-side * 0.03, 0, 0.18))
					_box(item, at + Vector3(0, 0.014, -0.15), Vector3(0.16, 0.008, 0.012), "brass", true)
		else:
			for x in [-size.x * 0.27, size.x * 0.27]:
				for side in [-1.0, 1.0]:
					var at := Vector3(x, 0.79, side * (size.y * 0.5 - 0.22))
					_plate(item, at)
					_mug(item, at + Vector3(0.2, 0, -side * 0.09))
					_box(item, at + Vector3(-0.15, 0.014, 0), Vector3(0.012, 0.008, 0.16), "brass", true)
		_bottle(item, Vector3(-0.14, 0.78, 0))
		_box(item, Vector3(0.22, 0.793, 0.02), Vector3(0.3, 0.035, 0.18), "paper", true)
	_collision(item, Vector3(size.x, 0.78, size.y))
	return item

func _plate(parent: Node3D, at: Vector3) -> void:
	_cyl(parent, at, 0.112, 0.014, "ceramic")
	_ring(parent, at + Vector3.UP * 0.011, 0.101, 0.009, "ceramic")
	_cyl(parent, at + Vector3.UP * 0.012, 0.075, 0.006, "ceramic")

func _mug(parent: Node3D, at: Vector3) -> void:
	_cyl(parent, at + Vector3.UP * 0.05, 0.043, 0.1, "ceramic")
	_cyl(parent, at + Vector3.UP * 0.103, 0.034, 0.003, "dark")
	_ring(parent, at + Vector3.UP * 0.103, 0.04, 0.005, "ceramic")
	_ring(parent, at + Vector3(0.06, 0.055, 0), 0.033, 0.008, "ceramic", true)

func _bottle(parent: Node3D, at: Vector3) -> void:
	_cyl(parent, at + Vector3.UP * 0.09, 0.047, 0.18, "dark")
	_cyl(parent, at + Vector3.UP * 0.2, 0.047, 0.04, "dark", 0.018)
	_cyl(parent, at + Vector3.UP * 0.25, 0.018, 0.07, "dark")
	_cyl(parent, at + Vector3.UP * 0.29, 0.014, 0.018, "wood_light")
	_box(parent, at + Vector3(0, 0.12, -0.047), Vector3(0.056, 0.07, 0.005), "paper", true)

func chair(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var item := _group(parent, pos, "OakMessChair", yaw)
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.2]:
			_box(item, Vector3(x, 0.22, z), Vector3(0.045, 0.44, 0.05), "wood_dark")
		_box(item, Vector3(x, 0.7, 0.22), Vector3(0.05, 0.51, 0.05), "wood_dark")
		_box(item, Vector3(x, 0.16, 0), Vector3(0.03, 0.035, 0.4), "wood")
	for z in [-0.145, 0.0, 0.145]:
		_box(item, Vector3(0, 0.46, z), Vector3(0.46, 0.065, 0.138), "wood")
	for x in [-0.12, 0.0, 0.12]:
		_box(item, Vector3(x, 0.72, 0.22), Vector3(0.068, 0.39, 0.035), "wood_light")
	_box(item, Vector3(0, 0.95, 0.22), Vector3(0.49, 0.07, 0.06), "wood_dark")
	_collision(item, Vector3(0.5, 0.98, 0.55))
	return item

func bookshelf(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var item := _group(parent, pos, "ChartAndBookCabinet", yaw)
	_box(item, Vector3(0, 0.93, 0.165), Vector3(1.1, 1.86, 0.035), "wood_dark")
	for x in [-0.52, 0.52]:
		_box(item, Vector3(x, 0.93, 0), Vector3(0.065, 1.86, 0.36), "wood_dark")
	for y in [0.08, 0.57, 1.06, 1.55, 1.85]:
		_box(item, Vector3(0, y, 0), Vector3(1.1, 0.055, 0.39), "wood")
	for shelf in range(3):
		var base: float = 0.11 + shelf * 0.49
		for i in range(8):
			var height: float = 0.28 + float((i * 3 + shelf) % 4) * 0.035
			var x: float = -0.43 + i * 0.12
			var material: String = ["leather", "cloth", "wood_dark", "canvas"][(i + shelf) % 4]
			_box(item, Vector3(x, base + height * 0.5, -0.015), Vector3(0.085, height, 0.255), material)
			for edge in [0.045, height - 0.045]:
				_box(item, Vector3(x, base + edge, -0.148), Vector3(0.085, 0.012, 0.008), "paper", true)
		_pipe(item, Vector3(-0.47, base + 0.11, -0.19), Vector3(0.47, base + 0.11, -0.19), 0.009, "brass")
	for x in [-0.3, 0.0, 0.3]:
		var chart := _cyl(item, Vector3(x, 1.69, -0.03), 0.04, 0.26, "paper")
		chart.rotation.x = PI / 2.0
	_collision(item, Vector3(1.1, 1.88, 0.39))
	return item

func locker(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var item := _group(parent, pos, "CrewWardrobe", yaw)
	_box(item, Vector3(0, 0.91, 0), Vector3(0.68, 1.82, 0.5), "wood_dark")
	for x in [-0.235, -0.078, 0.078, 0.235]:
		_box(item, Vector3(x, 0.93, -0.263), Vector3(0.15, 1.62, 0.045), "wood")
	for y in [0.16, 1.03, 1.7]:
		_box(item, Vector3(0, y, -0.295), Vector3(0.61, 0.06, 0.035), "wood_light")
	for y in [0.35, 1.48]:
		_box(item, Vector3(-0.26, y, -0.32), Vector3(0.14, 0.06, 0.02), "iron", true)
	_box(item, Vector3(0.21, 0.96, -0.32), Vector3(0.035, 0.15, 0.04), "brass")
	_box(item, Vector3(0, 1.54, -0.3), Vector3(0.18, 0.075, 0.015), "brass", true)
	_text(item, Vector3(0, 1.54, -0.312), "CREW", 0.0009)
	_box(item, Vector3(0, 1.84, 0), Vector3(0.74, 0.06, 0.55), "wood_light")
	_collision(item, Vector3(0.74, 1.88, 0.6), Vector3(0, 0, -0.035))
	return item

func barrel(parent: Node3D, pos: Vector3) -> Node3D:
	var item := _group(parent, pos, "CooperedCask")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := [0.02, 0.12, 0.46, 0.82, 0.94]
	var radii := [0.27, 0.305, 0.33, 0.305, 0.27]
	for stave in range(20):
		var a0: float = float(stave) * TAU / 20.0 + 0.006
		var a1: float = float(stave + 1) * TAU / 20.0 - 0.006
		for row in range(4):
			var a := Vector3(cos(a0) * radii[row], heights[row], sin(a0) * radii[row])
			var b := Vector3(cos(a1) * radii[row], heights[row], sin(a1) * radii[row])
			var c := Vector3(cos(a1) * radii[row + 1], heights[row + 1], sin(a1) * radii[row + 1])
			var d := Vector3(cos(a0) * radii[row + 1], heights[row + 1], sin(a0) * radii[row + 1])
			for vertex in [a, b, c, a, c, d]:
				surface.set_uv(Vector2(atan2(vertex.z, vertex.x) / TAU, vertex.y))
				surface.add_vertex(vertex)
	surface.generate_normals()
	_mesh(item, surface.commit(), Vector3.ZERO, "wood")
	_cyl(item, Vector3(0, 0.925, 0), 0.263, 0.024, "wood_dark")
	for y in [0.14, 0.35, 0.65, 0.82]:
		_ring(item, Vector3(0, y, 0), 0.312 if y < 0.2 or y > 0.8 else 0.33, 0.018, "iron")
	_cyl(item, Vector3(0.09, 0.943, 0), 0.035, 0.018, "wood_light")
	for z in [-0.15, -0.05, 0.05, 0.15]:
		_box(item, Vector3(0, 0.94, z), Vector3(sqrt(0.25 * 0.25 - z * z) * 2.0, 0.004, 0.006), "dark", true)
	_collision(item, Vector3(0.66, 0.95, 0.66))
	return item

func stove(parent: Node3D, pos: Vector3) -> Node3D:
	var item := _group(parent, pos, "CastIronGalleyStove")
	for x in [-0.29, 0.29]:
		for z in [-0.24, 0.24]:
			_box(item, Vector3(x, 0.1, z), Vector3(0.07, 0.2, 0.07), "iron")
	_box(item, Vector3(0, 0.52, 0), Vector3(0.73, 0.77, 0.62), "iron")
	_box(item, Vector3(0, 0.935, 0), Vector3(0.79, 0.08, 0.69), "dark")
	for x in [-0.2, 0.2]:
		_cyl(item, Vector3(x, 0.983, -0.06), 0.13, 0.018, "iron")
		_ring(item, Vector3(x, 0.995, -0.06), 0.1, 0.006, "brass")
	_box(item, Vector3(0, 0.55, -0.331), Vector3(0.55, 0.43, 0.045), "dark")
	_box(item, Vector3(0, 0.51, -0.357), Vector3(0.34, 0.16, 0.015), "glow_amber", true)
	for x in [-0.13, -0.065, 0, 0.065, 0.13]:
		_box(item, Vector3(x, 0.51, -0.373), Vector3(0.024, 0.18, 0.035), "iron")
	_pipe(item, Vector3(-0.22, 0.77, -0.39), Vector3(0.22, 0.77, -0.39), 0.021, "brass")
	_pipe(item, Vector3(0.25, 0.98, 0.22), Vector3(0.25, 2.55, 0.22), 0.082, "iron")
	for y in [1.12, 1.9, 2.48]:
		_ring(item, Vector3(0.25, y, 0.22), 0.087, 0.012, "iron")
	# Copper kettle with lid, carrying handle and tapering spout.
	_cyl(item, Vector3(-0.2, 1.09, -0.06), 0.1, 0.17, "copper", 0.075)
	_cyl(item, Vector3(-0.2, 1.184, -0.06), 0.08, 0.02, "brass")
	_cyl(item, Vector3(-0.2, 1.207, -0.06), 0.018, 0.027, "wood_dark")
	_ring(item, Vector3(-0.2, 1.22, -0.06), 0.09, 0.012, "iron", true)
	_pipe(item, Vector3(-0.12, 1.07, -0.06), Vector3(-0.02, 1.17, -0.06), 0.018, "copper")
	_collision(item, Vector3(0.8, 1.28, 0.79), Vector3(0, 0, -0.04))
	return item

func desk(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var item := _group(parent, pos, "NavigatorsWritingDesk", yaw)
	_box(item, Vector3(0, 0.745, 0), Vector3(1.2, 0.07, 0.6), "wood_light")
	for x in [-0.51, 0.51]:
		for z in [-0.22, 0.22]:
			_box(item, Vector3(x, 0.36, z), Vector3(0.065, 0.72, 0.065), "wood_dark")
	_box(item, Vector3(0, 0.61, 0), Vector3(1.09, 0.19, 0.51), "wood")
	for x in [-0.29, 0.29]:
		_box(item, Vector3(x, 0.61, -0.268), Vector3(0.52, 0.16, 0.025), "wood_dark")
		_pipe(item, Vector3(x - 0.06, 0.61, -0.3), Vector3(x + 0.06, 0.61, -0.3), 0.009, "brass")
	var page := _box(item, Vector3(-0.1, 0.788, -0.02), Vector3(0.43, 0.009, 0.31), "paper", true)
	page.rotation.y = 0.13
	for line in range(7):
		_box(item, Vector3(-0.1, 0.796, -0.12 + line * 0.033), Vector3(0.28 - (line % 3) * 0.035, 0.002, 0.003), "wood_dark", true)
	_cyl(item, Vector3(0.31, 0.81, 0.12), 0.025, 0.055, "dark")
	_pipe(item, Vector3(0.31, 0.83, 0.12), Vector3(0.35, 1.01, 0.14), 0.0025, "wood_dark")
	_box(item, Vector3(-0.4, 0.815, 0.12), Vector3(0.21, 0.065, 0.29), "leather")
	_box(item, Vector3(-0.4, 0.815, -0.026), Vector3(0.18, 0.042, 0.009), "paper", true)
	_collision(item, Vector3(1.2, 0.79, 0.63))
	return item

func lantern(parent: Node3D, pos: Vector3) -> Node3D:
	var item := _group(parent, pos, "OilLantern")
	_cyl(item, Vector3(0, -0.15, 0), 0.105, 0.065, "brass")
	_cyl(item, Vector3(0, 0, 0), 0.065, 0.24, "glow_amber")
	_cyl(item, Vector3(0, 0.16, 0), 0.11, 0.065, "iron", 0.065)
	_cyl(item, Vector3(0, 0.205, 0), 0.044, 0.04, "brass")
	for i in range(4):
		var angle: float = i * PI / 2.0
		_pipe(item, Vector3(cos(angle) * 0.088, -0.13, sin(angle) * 0.088), Vector3(cos(angle) * 0.088, 0.14, sin(angle) * 0.088), 0.008, "iron")
	_ring(item, Vector3(0, -0.105, 0), 0.089, 0.008, "iron")
	_ring(item, Vector3(0, 0.1, 0), 0.089, 0.008, "iron")
	_ring(item, Vector3(0, 0.27, 0), 0.055, 0.008, "iron", true)
	return item
