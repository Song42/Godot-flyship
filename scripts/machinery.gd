extends Node3D
## Hand-built mechanical props. All positions are relative to the floor except
## fans, valve wheels and lamps, whose supplied positions are their centres.

const Geometry = preload("res://scripts/geometry.gd")

var materials: Dictionary = {}
var rotors: Array[Dictionary] = []
var pistons: Array[Dictionary] = []
var clock: float = 0.0

func configure(palette: Dictionary) -> void:
	materials = palette.duplicate()
	var defaults := {
		"iron": Color("343e40"), "steel": Color("69797b"),
		"brass": Color("927043"), "copper": Color("98623f"),
		"dark": Color("11191d"), "rubber": Color("181b1c"),
		"glow_amber": Color("ffc779"), "glow_cyan": Color("8be0d8"),
		"red": Color("9f382d"), "glass": Color("263f40"),
		"wood": Color("513721"), "wood_dark": Color("2d2118"),
		"wood_light": Color("785a39"), "paper": Color("c3ad7c"),
		"leather": Color("362820"), "cloth": Color("5b5341")}
	for key in defaults:
		if not materials.has(key):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = defaults[key]
			mat.metallic = 0.55 if key in ["iron", "steel", "brass", "copper"] else 0.0
			mat.roughness = 0.72 if key in ["brass", "steel"] else 0.9
			if str(key).begins_with("glow"):
				mat.emission_enabled = true
				mat.emission = defaults[key]
				mat.emission_energy_multiplier = 2.5
			materials[key] = mat

func _ready() -> void:
	if materials.is_empty():
		configure({})

func _process(delta: float) -> void:
	clock += delta
	for entry in rotors:
		var rotor: Node3D = entry.node
		rotor.rotate_object_local(entry.axis, delta * entry.speed)
	for entry in pistons:
		var piston: Node3D = entry.node
		piston.position.z = entry.rest + sin(clock * 3.5 + entry.phase) * 0.16

func _group(parent: Node3D, pos: Vector3, title: String, yaw: float = 0.0) -> Node3D:
	if materials.is_empty():
		configure({})
	var group := Node3D.new()
	group.name = title
	parent.add_child(group)
	group.position = pos
	group.rotation.y = yaw
	return group

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: String, detail: bool = false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = materials.get(material, materials["iron"])
	parent.add_child(item)
	item.position = pos
	if detail:
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: String, detail: bool = false) -> MeshInstance3D:
	var shape: Mesh
	var minimum := minf(size.x, minf(size.y, size.z))
	if minimum >= 0.10:
		shape = Geometry.beveled_box(size, minf(0.025, minimum * 0.15))
	else:
		var cube := BoxMesh.new()
		cube.size = size
		shape = cube
	return _mesh(parent, shape, pos, material, detail)

func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, material: String, detail: bool = false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24 if radius > 0.18 else 12
	return _mesh(parent, shape, pos, material, detail)

func _pipe(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: String) -> MeshInstance3D:
	var item := _cyl(parent, (a + b) * 0.5, radius, a.distance_to(b), material)
	item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return item

func _ring(parent: Node3D, pos: Vector3, radius: float, tube: float, material: String, front: bool = false) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - tube
	shape.outer_radius = radius + tube
	shape.rings = 32
	shape.ring_segments = 8
	var item := _mesh(parent, shape, pos, material, tube < 0.03)
	if front:
		item.rotation.x = PI / 2.0
	return item

func _collision(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	collision.position = pos

func _text(parent: Node3D, pos: Vector3, value: String, font_size: int = 32, scale_value: float = 0.005, color: Color = Color("cfcec0")) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = font_size
	label.pixel_size = scale_value
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = true
	label.double_sided = true
	parent.add_child(label)
	label.position = pos
	label.rotation.y = PI
	return label

func _bolt_ring(parent: Node3D, pos: Vector3, radius: float, count: int = 12, front: bool = true) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = 0.035
	shape.bottom_radius = 0.035
	shape.height = 0.038
	shape.radial_segments = 6
	shape.material = materials["steel"]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = shape
	multi.instance_count = count
	for i in range(count):
		var angle: float = TAU * float(i) / count
		var p := Vector3(cos(angle) * radius, sin(angle) * radius, 0.0) if front else Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var basis := Basis(Vector3.RIGHT, PI / 2.0) if front else Basis.IDENTITY
		multi.set_instance_transform(i, Transform3D(basis, pos + p))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _gauge(parent: Node3D, pos: Vector3, radius: float = 0.21, value: String = "BAR", needle: float = -0.5) -> Node3D:
	var gauge := _group(parent, pos, "PressureGauge")
	var housing := _cyl(gauge, Vector3.ZERO, radius + 0.035, 0.09, "dark", true)
	housing.rotation.x = PI / 2.0
	var face := _cyl(gauge, Vector3(0, 0, -0.054), radius, 0.012, "paper", true)
	face.rotation.x = PI / 2.0
	_ring(gauge, Vector3(0, 0, -0.063), radius, 0.019, "brass", true)
	for i in range(11):
		var angle := -PI * 0.77 + float(i) * PI * 1.54 / 10.0
		var mark := _box(gauge, Vector3(sin(angle) * radius * 0.76, cos(angle) * radius * 0.76, -0.066), Vector3(0.012, radius * 0.17, 0.01), "dark", true)
		mark.rotation.z = -angle
	var hand := _box(gauge, Vector3(sin(needle) * radius * 0.3, cos(needle) * radius * 0.3, -0.08), Vector3(0.016, radius * 0.65, 0.012), "red", true)
	hand.rotation.z = -needle
	_text(gauge, Vector3(0, -radius * 0.4, -0.08), value, 24, radius * 0.004, Color("182428"))
	return gauge

func make_engine(parent: Node3D, pos: Vector3) -> Node3D:
	var engine := _group(parent, pos, "ReciprocatingEngine")
	_box(engine, Vector3(0, 0.18, 0), Vector3(4.6, 0.36, 8.8), "dark")
	_box(engine, Vector3(0, 0.43, 0), Vector3(4.3, 0.14, 8.5), "steel")
	for side in [-1.0, 1.0]:
		_box(engine, Vector3(side * 1.82, 0.67, 0), Vector3(0.42, 0.42, 8.0), "iron")
		for z in [-2.8, -0.9, 1.0, 2.9]:
			_box(engine, Vector3(side * 1.25, 1.05, z), Vector3(0.92, 1.0, 0.36), "iron")
			_box(engine, Vector3(side * 1.25, 1.52, z), Vector3(1.22, 0.2, 0.52), "brass")
		var cylinder := _cyl(engine, Vector3(side * 1.13, 2.22, 0.25), 0.75, 5.55, "iron")
		cylinder.rotation.x = PI / 2.0
		for z in [-2.56, -1.66, -0.76, 0.14, 1.04, 1.94, 3.05]:
			_ring(engine, Vector3(side * 1.13, 2.22, z), 0.77, 0.07, "brass", true)
		var cap := _cyl(engine, Vector3(side * 1.13, 2.22, -2.63), 0.76, 0.17, "dark")
		cap.rotation.x = PI / 2.0
		_bolt_ring(engine, Vector3(side * 1.13, 2.22, -2.74), 0.62, 14)
		_pipe(engine, Vector3(side * 1.13, 2.22, -2.75), Vector3(side * 1.13, 2.22, -3.72), 0.13, "steel")
		var rod := _box(engine, Vector3(side * 1.13, 2.22, -3.35), Vector3(0.32, 0.38, 0.8), "brass")
		pistons.append({"node": rod, "rest": -3.35, "phase": side * PI * 0.5})
		_pipe(engine, Vector3(side * 1.13, 2.7, 2.4), Vector3(side * 1.13, 3.75, 2.4), 0.16, "copper")
		_pipe(engine, Vector3(side * 1.13, 3.75, 2.4), Vector3(side * 1.13, 3.75, -1.2), 0.16, "copper")
		_pipe(engine, Vector3(side * 1.13, 3.75, -1.2), Vector3(side * 1.13, 2.8, -1.2), 0.16, "copper")
		for z in [-1.2, 0.1, 1.4, 2.4]:
			var flange := _cyl(engine, Vector3(side * 1.13, 3.75, z), 0.235, 0.09, "brass")
			flange.rotation.x = PI / 2.0
		_gauge(engine, Vector3(side * 1.13, 3.2, -1.8), 0.22, "MPa", side * 0.7)
	var rotor := _group(engine, Vector3(0, 2.0, -3.9), "Flywheel")
	_ring(rotor, Vector3.ZERO, 1.37, 0.14, "iron", true)
	_ring(rotor, Vector3(0, 0, -0.06), 1.2, 0.045, "brass", true)
	var hub := _cyl(rotor, Vector3.ZERO, 0.28, 0.38, "brass")
	hub.rotation.x = PI / 2.0
	for i in range(8):
		var angle: float = i * TAU / 8.0
		_pipe(rotor, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * 1.24, 0.08, "iron")
	rotors.append({"node": rotor, "axis": Vector3.FORWARD, "speed": 1.3})
	_box(engine, Vector3(0, 0.85, -4.05), Vector3(0.8, 1.3, 0.35), "iron")
	_box(engine, Vector3(0, 1.02, -4.25), Vector3(0.7, 0.3, 0.025), "brass", true)
	_text(engine, Vector3(0, 1.04, -4.28), "AEOLUS / XII", 28, 0.002)
	_pipe(engine, Vector3(-1.13, 3.75, 2.4), Vector3(1.13, 3.75, 2.4), 0.2, "copper")
	for z in [-2.0, 0.0, 2.0]:
		_box(engine, Vector3(0, 0.54, z), Vector3(0.8, 0.02, 0.12), "brass", true)
	_collision(engine, Vector3(0, 1.85, 0), Vector3(4.35, 3.7, 8.7))
	return engine

func make_boiler(parent: Node3D, pos: Vector3) -> Node3D:
	var boiler := _group(parent, pos, "PressureBoiler")
	_cyl(boiler, Vector3(0, 0.24, 0), 1.3, 0.48, "iron")
	_cyl(boiler, Vector3(0, 1.95, 0), 1.08, 3.15, "iron")
	for y in [0.52, 1.3, 2.55, 3.48]:
		_ring(boiler, Vector3(0, y, 0), 1.09, 0.075, "brass")
		_bolt_ring(boiler, Vector3(0, y + 0.08, 0), 1.1, 16, false)
	_cyl(boiler, Vector3(0, 3.62, 0), 0.86, 0.22, "brass")
	_cyl(boiler, Vector3(0, 3.94, 0), 0.25, 0.6, "copper")
	_pipe(boiler, Vector3(0, 4.24, 0), Vector3(1.32, 4.24, 0), 0.25, "copper")
	_box(boiler, Vector3(0, 1.2, -1.09), Vector3(1.2, 1.14, 0.24), "dark")
	_box(boiler, Vector3(0, 1.2, -1.23), Vector3(0.95, 0.81, 0.025), "glow_amber")
	for x in [-0.36, -0.18, 0.0, 0.18, 0.36]:
		_box(boiler, Vector3(x, 1.2, -1.27), Vector3(0.055, 0.86, 0.05), "iron")
	_box(boiler, Vector3(0, 0.74, -1.29), Vector3(1.17, 0.12, 0.09), "brass")
	_gauge(boiler, Vector3(0.45, 2.67, -1.04), 0.22, "PSI", 0.4)
	_pipe(boiler, Vector3(-0.65, 0.55, -0.95), Vector3(-0.65, 3.2, -0.95), 0.065, "copper")
	for y in [1.7, 2.8]:
		_ring(boiler, Vector3(-0.65, y, -0.95), 0.09, 0.022, "brass")
	make_valve(boiler, Vector3(-0.65, 2.08, -1.12))
	_text(boiler, Vector3(0, 3.13, -1.07), "CAUTION / LIVE STEAM", 26, 0.0025)
	var fire := OmniLight3D.new()
	fire.light_color = Color("ffa14d")
	fire.light_energy = 1.1
	fire.omni_range = 3.5
	fire.shadow_enabled = false
	boiler.add_child(fire)
	fire.position = Vector3(0, 1.2, -1.6)
	_collision(boiler, Vector3(0, 1.8, 0), Vector3(2.55, 3.6, 2.7))
	return boiler

func make_console(parent: Node3D, pos: Vector3, rotation_y: float = 0.0) -> Node3D:
	var console := _group(parent, pos, "InstrumentConsole", rotation_y)
	_box(console, Vector3(0, 0.6, 0.1), Vector3(2.6, 1.2, 0.9), "wood")
	_box(console, Vector3(0, 0.09, 0.0), Vector3(2.72, 0.18, 1.16), "wood_dark")
	_box(console, Vector3(0, 1.32, 0.31), Vector3(2.64, 0.72, 0.3), "wood_dark")
	_box(console, Vector3(0, 1.32, 0.142), Vector3(2.48, 0.57, 0.035), "wood_light")
	for x in [-0.85, -0.28, 0.29]:
		_gauge(console, Vector3(x, 1.37, 0.09), 0.17, "RPM" if x < -0.5 else "BAR", x)
	_gauge(console, Vector3(0.9, 1.37, 0.09), 0.135, "VOLTS", 0.75)
	var control_deck := _box(console, Vector3(0, 1.18, -0.3), Vector3(2.64, 0.13, 0.82), "wood_dark")
	control_deck.rotation.x = -0.13
	for x in [-1.03, -0.68, -0.33, 0.02, 0.37]:
		_cyl(console, Vector3(x, 1.29, -0.32), 0.07, 0.035, "brass", true)
		_cyl(console, Vector3(x, 1.32, -0.32), 0.038, 0.025, "glow_amber" if x < -0.5 else "leather", true)
		_box(console, Vector3(x, 1.285, -0.55), Vector3(0.17, 0.015, 0.08), "paper", true)
	for x in [0.79, 1.08]:
		_box(console, Vector3(x, 1.29, -0.36), Vector3(0.12, 0.04, 0.45), "dark")
		_pipe(console, Vector3(x, 1.3, -0.37), Vector3(x, 1.58, -0.51), 0.025, "steel")
		_cyl(console, Vector3(x, 1.6, -0.52), 0.055, 0.08, "leather")
	for x in [-1.08, 1.08]:
		for y in [0.22, 0.9]:
			var bolt := _cyl(console, Vector3(x, y, -0.37), 0.035, 0.025, "brass", true)
			bolt.rotation.x = PI / 2.0
	for y in range(7):
		_box(console, Vector3(0, 0.37 + y * 0.055, -0.365), Vector3(1.2, 0.022, 0.025), "dark", true)
	_text(console, Vector3(0, 0.89, -0.37), "HARTWELL & SONS / STEAM GOVERNOR", 26, 0.0024)
	_collision(console, Vector3(0, 0.85, 0), Vector3(2.65, 1.7, 1.15))
	return console

func make_crate(parent: Node3D, pos: Vector3, size: Vector3 = Vector3(1.6, 1.3, 1.3)) -> Node3D:
	var crate := _group(parent, pos, "CargoCrate")
	_box(crate, Vector3(0, size.y * 0.5, 0), size, "wood")
	var inset := size - Vector3(0.18, 0.18, 0.18)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(crate, Vector3(x * (size.x * 0.5 - 0.035), size.y * 0.5, z * (size.z * 0.5 - 0.035)), Vector3(0.11, size.y + 0.03, 0.11), "wood_dark")
	for y in [0.07, size.y - 0.07]:
		_box(crate, Vector3(0, y, 0), Vector3(size.x + 0.04, 0.13, size.z + 0.04), "wood_dark")
	for x in [-0.28, 0.28]:
		_box(crate, Vector3(size.x * x, size.y * 0.5, 0), Vector3(0.09, size.y + 0.055, size.z + 0.055), "iron")
	# Recessed corrugation, cast corner protectors and two-sided manifests make
	# the crates readable from the main cargo aisle as well as from behind.
	for facing in [-1.0, 1.0]:
		var front_z: float = facing * (size.z * 0.5 + 0.02)
		for rib in range(8):
			var at_x: float = -size.x * 0.4 + float(rib) * size.x * 0.8 / 7.0
			_box(crate, Vector3(at_x, size.y * 0.5, front_z), Vector3(0.045, inset.y - 0.1, 0.045), "wood_light", true)
		var plaque_width: float = minf(0.76, size.x * 0.5)
		_box(crate, Vector3(0, size.y * 0.56, front_z + facing * 0.035), Vector3(plaque_width, size.y * 0.26, 0.034), "dark", true)
		var label := _text(crate, Vector3(0, size.y * 0.58, front_z + facing * 0.055), "H & S / No. 184\nENGINE STORES", 28, minf(0.0024, size.y * 0.0025), Color("c4b38e"))
		label.rotation.y = PI if facing < 0.0 else 0.0
		_box(crate, Vector3(0, size.y * 0.39, front_z + facing * 0.043), Vector3(plaque_width, 0.025, 0.027), "brass", true)
		for x in [-1.0, 1.0]:
			for y in [0.2, size.y - 0.2]:
				_box(crate, Vector3(x * (size.x * 0.5 - 0.12), y, front_z + facing * 0.022), Vector3(0.24, 0.25, 0.065), "iron")
		var side_x: float = facing * (size.x * 0.5 + 0.023)
		for rib in range(6):
			var at_z: float = -size.z * 0.36 + float(rib) * size.z * 0.72 / 5.0
			_box(crate, Vector3(side_x, size.y * 0.5, at_z), Vector3(0.045, inset.y - 0.1, 0.05), "wood_light", true)
		_box(crate, Vector3(side_x + facing * 0.018, size.y * 0.5, 0), Vector3(0.025, size.y * 0.25, size.z * 0.37), "dark", true)
		var weight := _text(crate, Vector3(side_x + facing * 0.035, size.y * 0.5, 0), "↑  840 KG  ↑", 28, minf(0.0022, size.z * 0.0016), Color("b6a378"))
		weight.rotation.y = facing * PI / 2.0
	for rib in range(5):
		_box(crate, Vector3(0, size.y + 0.023, -size.z * 0.35 + rib * size.z * 0.175), Vector3(size.x * 0.84, 0.035, 0.045), "dark", true)
	for x in [-0.5, 0.5]:
		_box(crate, Vector3(x * size.x * 0.7, size.y - 0.13, -size.z * 0.5 - 0.02), Vector3(0.15, 0.09, 0.04), "brass", true)
	_collision(crate, Vector3(0, size.y * 0.5, 0), size)
	return crate

func make_terminal(parent: Node3D, pos: Vector3, rotation_y: float = 0.0) -> Node3D:
	var terminal := _group(parent, pos, "PhosphorTerminal", rotation_y)
	_box(terminal, Vector3(0, 1.08, 0.13), Vector3(1.42, 2.16, 0.54), "iron")
	_box(terminal, Vector3(0, 0.11, 0.13), Vector3(1.52, 0.22, 0.65), "dark")
	_box(terminal, Vector3(0, 1.65, -0.19), Vector3(1.21, 0.86, 0.23), "dark")
	_box(terminal, Vector3(0, 1.65, -0.318), Vector3(1.04, 0.67, 0.025), "brass")
	_box(terminal, Vector3(0, 1.65, -0.336), Vector3(0.94, 0.57, 0.019), "screen" if materials.has("screen") else "glow_cyan", true)
	_text(terminal, Vector3(0, 1.81, -0.354), "NOCTURNE // ENGINEERING", 24, 0.0018, Color("b1ffcc"))
	_text(terminal, Vector3(-0.01, 1.59, -0.355), "CORE PRESSURE  074.8\nHULL INTEGRITY  NOMINAL\nUPLINK . . . . . LOST", 24, 0.00165, Color("85cfa5"))
	_box(terminal, Vector3(0, 1.03, -0.28), Vector3(1.26, 0.16, 0.65), "iron")
	for row in range(3):
		for column in range(10):
			_box(terminal, Vector3(-0.44 + column * 0.098, 1.12, -0.13 - row * 0.102), Vector3(0.075, 0.035, 0.069), "rubber", true)
	for x in [-0.46, 0.46]:
		_gauge(terminal, Vector3(x, 0.75, -0.165), 0.115, "V", x)
	for y in range(5):
		_box(terminal, Vector3(0, 0.3 + y * 0.045, -0.155), Vector3(0.74, 0.018, 0.02), "dark", true)
	_text(terminal, Vector3(0, 2.05, -0.155), "AUXILIARY CONTROL / 07", 24, 0.0022)
	_pipe(terminal, Vector3(-0.55, 2.16, 0.13), Vector3(-0.55, 2.65, 0.13), 0.045, "copper")
	_pipe(terminal, Vector3(0.55, 2.16, 0.13), Vector3(0.55, 2.5, 0.13), 0.045, "copper")
	_collision(terminal, Vector3(0, 1.1, 0), Vector3(1.5, 2.2, 0.95))
	return terminal

func make_tank(parent: Node3D, pos: Vector3) -> Node3D:
	var tank := _group(parent, pos, "AccumulatorTank")
	_cyl(tank, Vector3(0, 0.14, 0), 0.77, 0.28, "dark")
	_cyl(tank, Vector3(0, 1.52, 0), 0.63, 2.7, "copper")
	for y in [0.34, 1.12, 2.0, 2.7]:
		_ring(tank, Vector3(0, y, 0), 0.65, 0.055, "iron")
	_cyl(tank, Vector3(0, 2.94, 0), 0.4, 0.24, "brass")
	_cyl(tank, Vector3(0, 3.1, 0), 0.12, 0.15, "dark")
	_pipe(tank, Vector3(0.54, 0.6, -0.35), Vector3(0.54, 2.55, -0.35), 0.045, "steel")
	_gauge(tank, Vector3(0, 2.39, -0.64), 0.18, "PSI", 0.2)
	_text(tank, Vector3(0, 1.47, -0.64), "CONDENSATE\n02", 30, 0.0035)
	_collision(tank, Vector3(0, 1.5, 0), Vector3(1.52, 3.0, 1.52))
	return tank

func make_fan(parent: Node3D, pos: Vector3, rotation_y: float = 0.0) -> Node3D:
	var fan := _group(parent, pos, "VentilationFan", rotation_y)
	_box(fan, Vector3(0, 0, 0.12), Vector3(1.82, 1.82, 0.22), "dark")
	_ring(fan, Vector3.ZERO, 0.82, 0.055, "iron", true)
	_ring(fan, Vector3(0, 0, -0.03), 0.76, 0.022, "brass", true)
	_bolt_ring(fan, Vector3(0, 0, -0.03), 0.84, 12)
	var rotor := _group(fan, Vector3(0, 0, -0.025), "Rotor")
	var hub := _cyl(rotor, Vector3.ZERO, 0.18, 0.1, "steel")
	hub.rotation.x = PI / 2.0
	for i in range(6):
		var angle: float = i * TAU / 6.0
		var blade := _box(rotor, Vector3(cos(angle) * 0.43, sin(angle) * 0.43, 0), Vector3(0.56, 0.18, 0.035), "steel")
		blade.rotation.z = angle - 0.25
	rotors.append({"node": rotor, "axis": Vector3.FORWARD, "speed": 2.6})
	for i in range(-3, 4):
		var offset: float = i * 0.19
		var length: float = sqrt(0.72 * 0.72 - offset * offset) * 2.0
		_box(fan, Vector3(offset, 0, -0.12), Vector3(0.012, length, 0.018), "dark", true)
		_box(fan, Vector3(0, offset, -0.12), Vector3(length, 0.012, 0.018), "dark", true)
	return fan

func make_valve(parent: Node3D, pos: Vector3, rotation_y: float = 0.0) -> Node3D:
	var valve := _group(parent, pos, "HandValve", rotation_y)
	var spindle := _cyl(valve, Vector3(0, 0, 0.1), 0.05, 0.25, "brass")
	spindle.rotation.x = PI / 2.0
	_ring(valve, Vector3.ZERO, 0.25, 0.036, "red", true)
	var hub := _cyl(valve, Vector3.ZERO, 0.065, 0.07, "brass")
	hub.rotation.x = PI / 2.0
	for i in range(5):
		var angle: float = i * TAU / 5.0
		_pipe(valve, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * 0.24, 0.022, "red")
	return valve

func make_bench(parent: Node3D, pos: Vector3) -> Node3D:
	var bench := _group(parent, pos, "MaintenanceBench")
	_box(bench, Vector3(0, 0.84, 0), Vector3(2.8, 0.12, 1.0), "wood_light")
	for x in [-1.18, 1.18]:
		for z in [-0.36, 0.36]:
			_box(bench, Vector3(x, 0.41, z), Vector3(0.1, 0.82, 0.1), "iron")
	_box(bench, Vector3(0, 0.18, 0), Vector3(2.6, 0.06, 0.85), "dark")
	_box(bench, Vector3(-0.7, 0.97, -0.05), Vector3(0.55, 0.17, 0.4), "dark")
	for x in [-0.9, -0.5]:
		_box(bench, Vector3(x, 1.14, -0.05), Vector3(0.1, 0.19, 0.29), "steel")
	_pipe(bench, Vector3(-1.12, 1.03, -0.05), Vector3(-0.36, 1.03, -0.05), 0.03, "brass")
	_ring(bench, Vector3(0.6, 0.93, 0), 0.2, 0.04, "brass")
	_box(bench, Vector3(0.2, 0.92, -0.13), Vector3(0.045, 0.035, 0.37), "steel", true)
	_box(bench, Vector3(0.21, 0.92, -0.32), Vector3(0.12, 0.045, 0.07), "steel", true)
	_collision(bench, Vector3(0, 0.46, 0), Vector3(2.8, 0.92, 1.0))
	return bench

func make_hanging_lamp(parent: Node3D, pos: Vector3) -> Node3D:
	var lamp := _group(parent, pos, "PendantLamp")
	_cyl(lamp, Vector3(0, 0.37, 0), 0.025, 0.75, "dark")
	var shade := CylinderMesh.new()
	shade.top_radius = 0.13
	shade.bottom_radius = 0.45
	shade.height = 0.24
	shade.radial_segments = 24
	_mesh(lamp, shade, Vector3.ZERO, "iron")
	_cyl(lamp, Vector3(0, -0.13, 0), 0.38, 0.025, "glow_amber", true)
	_ring(lamp, Vector3(0, -0.15, 0), 0.42, 0.028, "brass")
	var light := OmniLight3D.new()
	light.light_color = Color("ffd5a0")
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.shadow_enabled = true
	light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	lamp.add_child(light)
	light.position.y = -0.3
	return lamp

func make_rail(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var rail := _group(parent, Vector3.ZERO, "SafetyRail")
	var sections: int = maxi(1, ceili(a.distance_to(b) / 1.8))
	for i in range(sections + 1):
		var p: Vector3 = a.lerp(b, float(i) / sections)
		_pipe(rail, p, p + Vector3.UP * 1.0, 0.045, "iron")
		_cyl(rail, p + Vector3.UP * 0.03, 0.12, 0.06, "dark")
	_pipe(rail, a + Vector3.UP, b + Vector3.UP, 0.045, "brass")
	_pipe(rail, a + Vector3.UP * 0.5, b + Vector3.UP * 0.5, 0.025, "iron")
	var midpoint := (a + b) * 0.5 + Vector3.UP * 0.5
	var body := StaticBody3D.new()
	rail.add_child(body)
	body.position = midpoint
	body.quaternion = Quaternion(Vector3.RIGHT, (b - a).normalized())
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(a.distance_to(b), 1.1, 0.1)
	collider.shape = shape
	body.add_child(collider)
	return rail
