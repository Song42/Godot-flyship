extends Node3D
## Compact timber hull building blocks. Rect2.y maps to world Z; floor level is Y=0.

const Geometry = preload("res://scripts/geometry.gd")
var mat: Dictionary = {}
var kit: Node3D
var furniture: Node3D
var doors: Array[Dictionary] = []
var interactables: Array[Node3D] = []
var light_sources: Array[Dictionary] = []

func _material(value: Variant) -> Material:
	if value is Material:
		return value as Material
	return mat.get(str(value), mat.get("wood")) as Material

func _local_box(parent: Node3D, pos: Vector3, size: Vector3, material: Variant, collision: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Geometry.beveled_box(size, 0.035)
	mesh.material_override = _material(material)
	if not collision and (minf(size.x, minf(size.y, size.z)) < 0.06 or maxf(size.x, maxf(size.y, size.z)) < 0.3):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.position = pos
	if collision:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size.abs()
		shape_node.shape = shape
		mesh.add_child(body)
		body.add_child(shape_node)
	return mesh

func _box(title: String, pos: Vector3, size: Vector3, material: Variant, collision: bool = true) -> MeshInstance3D:
	var mesh := _local_box(self, pos, size, material, collision)
	mesh.name = title
	return mesh

func _floor(rect: Rect2) -> void:
	var center := rect.get_center()
	_box("TimberDeck", Vector3(center.x, -0.09, center.y), Vector3(rect.size.x, 0.18, rect.size.y), "floor")

func _roof(rect: Rect2, height: float) -> void:
	var center := rect.get_center()
	_box("CeilingPlanks", Vector3(center.x, height + 0.08, center.y), Vector3(rect.size.x, 0.16, rect.size.y), "ceiling")
	var z := rect.position.y + 0.28
	var knee := minf(0.65, rect.size.x * 0.18)
	while z < rect.end.y - 0.1:
		_box("TransverseBeam", Vector3(center.x, height - 0.105, z), Vector3(rect.size.x, 0.21, 0.17), "wood_dark")
		for side in [-1.0, 1.0]:
			var x: float = center.x + side * (rect.size.x * 0.5 - 0.11)
			_timber_between(Vector3(x, height - knee - 0.12, z), Vector3(x - side * knee, height - 0.16, z), 0.12)
		z += 1.65

func _timber_between(a: Vector3, b: Vector3, thickness: float) -> MeshInstance3D:
	var beam := _box("KneeBrace", (a + b) * 0.5, Vector3(thickness, a.distance_to(b), thickness), "wood_dark", false)
	beam.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return beam

func _opening(center: float) -> Vector2:
	return Vector2(center - 0.72, center + 0.72)

func _wall_x(x: float, begin: float, end: float, height: float, openings: Array = []) -> void:
	_wall_run(true, x, begin, end, height, openings)

func _wall_z(z: float, begin: float, end: float, height: float, openings: Array = []) -> void:
	_wall_run(false, z, begin, end, height, openings)

func _wall_run(along_z: bool, fixed: float, begin: float, end: float, height: float, openings: Array) -> void:
	var ordered: Array = openings.duplicate()
	ordered.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := begin
	for raw in ordered:
		var span: Vector2 = raw
		var start := clampf(span.x, begin, end)
		var finish := clampf(span.y, begin, end)
		if finish <= cursor:
			continue
		if start > cursor:
			_wall_segment(along_z, fixed, cursor, start, height)
		var lintel := maxf(height - 2.22, 0.0)
		if lintel > 0.01:
			var middle := (maxf(start, cursor) + finish) * 0.5
			var length_m := finish - maxf(start, cursor)
			var pos := Vector3(fixed, 2.22 + lintel * 0.5, middle) if along_z else Vector3(middle, 2.22 + lintel * 0.5, fixed)
			var size := Vector3(0.18, lintel, length_m) if along_z else Vector3(length_m, lintel, 0.18)
			_box("OpeningHeader", pos, size, "wall")
		cursor = finish
	if cursor < end:
		_wall_segment(along_z, fixed, cursor, end, height)

func _wall_segment(along_z: bool, fixed: float, begin: float, end: float, height: float) -> void:
	var length_m := end - begin
	if length_m <= 0.005:
		return
	var center := (begin + end) * 0.5
	var pos := Vector3(fixed, height * 0.5, center) if along_z else Vector3(center, height * 0.5, fixed)
	var size := Vector3(0.18, height, length_m) if along_z else Vector3(length_m, height, 0.18)
	_box("HullPlanks", pos, size, "wall")
	for trim_y in [0.09, height - 0.07]:
		var trim_pos := Vector3(fixed, trim_y, center) if along_z else Vector3(center, trim_y, fixed)
		var trim_size := Vector3(0.22, 0.13, length_m) if along_z else Vector3(length_m, 0.13, 0.22)
		_box("HullMoulding", trim_pos, trim_size, "wood_dark", false)
	var post := begin + 0.07
	while post < end - 0.04:
		var post_pos := Vector3(fixed, height * 0.5, post) if along_z else Vector3(post, height * 0.5, fixed)
		var post_size := Vector3(0.24, height, 0.1) if along_z else Vector3(0.1, height, 0.24)
		_box("HullFrame", post_pos, post_size, "wood_dark", false)
		post += 1.65

func _window_wall_x(x: float, begin: float, end: float, windows: Array, height: float, doors_openings: Array = []) -> void:
	var openings: Array = doors_openings.duplicate()
	for raw in windows:
		var z: float = raw
		openings.append(Vector2(z - 0.48, z + 0.48))
	_wall_x(x, begin, end, height, openings)
	var yaw := -PI * 0.5 if x >= 0.0 else PI * 0.5
	for raw in windows:
		var z: float = raw
		_window(Vector3(x, 1.64, z), Vector2(0.96, 1.12), yaw)

func _window(pos: Vector3, size: Vector2, yaw: float) -> Node3D:
	var window := Node3D.new()
	window.name = "HullWindow"
	add_child(window)
	window.position = pos
	window.rotation.y = yaw
	var half := size * 0.5
	var sill_height := pos.y - half.y
	if sill_height > 0.0:
		_local_box(window, Vector3(0, -half.y - sill_height * 0.5, 0), Vector3(size.x, sill_height, 0.18), "wall")
	var top_fill := 2.22 - pos.y - half.y
	if top_fill > 0.005:
		_local_box(window, Vector3(0, half.y + top_fill * 0.5, 0), Vector3(size.x, top_fill, 0.18), "wall")
	for side in [-1.0, 1.0]:
		_local_box(window, Vector3(side * (half.x - 0.03), 0, 0), Vector3(0.06, size.y + 0.08, 0.24), "wood_dark", false)
		_local_box(window, Vector3(0, side * half.y, 0), Vector3(size.x + 0.08, 0.065, 0.24), "wood_dark", false)
	_local_box(window, Vector3(0, -half.y - 0.035, 0.065), Vector3(size.x + 0.16, 0.065, 0.34), "wood", false)
	_local_box(window, Vector3.ZERO, Vector3(size.x - 0.11, size.y - 0.07, 0.018), "glass", true)
	_local_box(window, Vector3(0, 0, 0.025), Vector3(0.032, size.y - 0.08, 0.035), "wood_light", false)
	_local_box(window, Vector3(0, 0.05, 0.026), Vector3(size.x - 0.08, 0.029, 0.035), "wood_light", false)
	# The outer shutters stay folded back; curtains leave the centre view clear.
	for side in [-1.0, 1.0]:
		var shutter := Node3D.new()
		window.add_child(shutter)
		shutter.position = Vector3(side * (half.x + 0.025), 0, -0.12)
		shutter.rotation.y = side * 0.28
		_local_box(shutter, Vector3(side * 0.17, 0, 0), Vector3(0.34, size.y - 0.06, 0.045), "wood_dark", false)
		for brace_y in [-half.y * 0.65, half.y * 0.65]:
			_local_box(shutter, Vector3(side * 0.17, brace_y, 0.028), Vector3(0.29, 0.055, 0.025), "iron", false)
		_curtain_strip(window, Vector3(side * (half.x - 0.08), 0.015, 0.16), 0.16, size.y + 0.02)
	_local_box(window, Vector3(0, half.y + 0.07, 0.16), Vector3(size.x + 0.24, 0.035, 0.04), "brass", false)
	return window

func _curtain_strip(parent: Node3D, pos: Vector3, width: float, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(10):
		var left := float(index) / 10.0
		var right := float(index + 1) / 10.0
		for uv in [Vector2(left, 0), Vector2(right, 1), Vector2(left, 1), Vector2(left, 0), Vector2(right, 0), Vector2(right, 1)]:
			var fold := sin(uv.x * TAU * 3.0) * 0.016
			surface.set_uv(uv)
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(Vector3((uv.x - 0.5) * width, (0.5 - uv.y) * height, fold))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = _material("canvas")
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.position = pos

func _arch(z: float, width: float, height: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * (width * 0.5 - 0.08)
		_box("PassageRib", Vector3(x, height * 0.5, z), Vector3(0.16, height, 0.18), "wood_dark", false)
		_timber_between(Vector3(x, height - 0.55, z), Vector3(x - side * 0.45, height - 0.12, z), 0.13)
	_box("PassageCrossbeam", Vector3(0, height - 0.08, z), Vector3(width, 0.16, 0.18), "wood_dark", false)

func _door(pos: Vector3, number: Variant, title: String, side_wall: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Door_%s" % str(number)
	add_child(root)
	root.position = pos
	root.rotation.y = PI * 0.5 if side_wall else 0.0
	var door_index := doors.size()
	root.set_meta("door_index", door_index)
	for side in [-1.0, 1.0]:
		_local_box(root, Vector3(side * 0.77, 1.13, 0), Vector3(0.12, 2.26, 0.22), "wood_dark")
	_local_box(root, Vector3(0, 2.19, 0), Vector3(1.66, 0.15, 0.23), "wood_dark", false)
	_local_box(root, Vector3(0, 2.32, 0), Vector3(1.29, 0.23, 0.11), "wood_dark", false)
	var panels: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var panel := Node3D.new()
		root.add_child(panel)
		panel.position.x = side * 0.35
		panel.set_meta("side", side)
		var leaf := _local_box(panel, Vector3(0, 1.06, 0), Vector3(0.69, 2.12, 0.1), "wood", true)
		leaf.get_child(0).set_meta("door_index", door_index)
		for rail_y in [0.16, 0.96, 1.98]:
			_local_box(panel, Vector3(0, rail_y, 0), Vector3(0.67, 0.085, 0.14), "wood_dark", false)
		for edge in [-0.29, 0.29]:
			_local_box(panel, Vector3(edge, 1.07, 0), Vector3(0.055, 2.03, 0.135), "wood_dark", false)
		for face in [-1.0, 1.0]:
			_local_box(panel, Vector3(-side * 0.2, 1.13, face * 0.087), Vector3(0.027, 0.19, 0.035), "brass", false)
		panels.append(panel)
	_sign("%s   %s" % [str(number), title], Vector3(0, 2.36, 0.062), 0.0, 30, 0.0023, root)
	_sign("%s   %s" % [str(number), title], Vector3(0, 2.36, -0.062), PI, 30, 0.0023, root)
	doors.append({"root": root, "open": false, "amount": 0.0, "panels": panels, "title": title})
	return root

func _rail(a: Vector3, b: Vector3) -> void:
	var length_m := a.distance_to(b)
	if length_m < 0.05:
		return
	var root := Node3D.new()
	root.name = "DeckBalustrade"
	add_child(root)
	root.position = (a + b) * 0.5
	var direction := (b - a).normalized()
	root.rotation.y = -atan2(direction.z, direction.x)
	_local_box(root, Vector3(0, 1.08, 0), Vector3(length_m + 0.06, 0.09, 0.12), "wood_dark", false)
	_local_box(root, Vector3(0, 0.17, 0), Vector3(length_m, 0.07, 0.075), "wood", false)
	var count := maxi(1, int(ceil(length_m / 0.25)))
	for index in range(count + 1):
		var x := -length_m * 0.5 + float(index) / float(count) * length_m
		var thickness := 0.075 if index == 0 or index == count else 0.038
		_local_box(root, Vector3(x, 0.61, 0), Vector3(thickness, 0.91, thickness), "wood_dark", false)
	var body := StaticBody3D.new()
	root.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length_m + 0.08, 1.45, 0.17)
	collider.shape = shape
	body.add_child(collider)
	collider.position.y = 0.725

func _lantern(pos: Vector3, energy: float = 1.0, radius: float = 5.0) -> OmniLight3D:
	if is_instance_valid(furniture) and furniture.has_method("lantern"):
		furniture.call("lantern", self, pos)
	return _point(pos, Color(1.0, 0.81, 0.59), energy, radius, light_sources.size() % 4 == 0)

func _point(pos: Vector3, color: Color, energy: float, radius: float, shadows: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	add_child(light)
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.35
	light.light_size = 0.17
	light.light_specular = 0.16
	light.shadow_enabled = shadows
	light.shadow_bias = 0.025
	light.distance_fade_enabled = true
	light.distance_fade_begin = 18.0
	light.distance_fade_length = 8.0
	light_sources.append({"light": light, "energy": energy, "phase": float(light_sources.size()) * 1.73})
	return light

func _pipe(a: Vector3, b: Vector3, radius: float, material: Variant) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(a.distance_to(b), 0.001)
	mesh.radial_segments = 20 if radius > 0.08 else 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(material)
	add_child(instance)
	instance.position = (a + b) * 0.5
	if a.distance_squared_to(b) > 0.000001:
		instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return instance

func _ring(pos: Vector3, radius: float, tube: float, material: Variant, rx: float = 0.0, rz: float = 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - tube, 0.001)
	mesh.outer_radius = radius + tube
	mesh.rings = 24
	mesh.ring_segments = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(material)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	instance.position = pos
	instance.rotation = Vector3(rx, 0, rz)
	return instance

func _sign(text: String, pos: Vector3, yaw: float, font_size: int, pixel: float = 0.005, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel
	label.modulate = Color(0.76, 0.67, 0.49)
	label.shaded = true
	label.outline_size = 0
	label.no_depth_test = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var destination := self if parent == null else parent
	destination.add_child(label)
	label.position = pos
	label.rotation.y = yaw
	return label

func _note(pos: Vector3, content: String, yaw: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "PinnedNote"
	add_child(root)
	root.position = pos
	root.rotation.y = yaw
	root.set_meta("note", content)
	var paper := _local_box(root, Vector3.ZERO, Vector3(0.30, 0.40, 0.012), "paper", true)
	paper.get_child(0).set_meta("note", content)
	_local_box(root, Vector3(0, 0.177, 0.012), Vector3(0.015, 0.015, 0.01), "brass", false)
	var label := _sign(content.left(120), Vector3(0, 0, 0.009), 0.0, 20, 0.001, root)
	label.width = 270.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.15, 0.10, 0.065)
	interactables.append(root)
	return root
