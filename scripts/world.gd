extends Node3D
## Entire vessel is assembled from reusable, authored architectural modules.
## Coordinates are metres. Bow is -Z, port is -X. No exterior sky or stars.

const MaterialLibrary = preload("res://scripts/materials.gd")
const Geometry = preload("res://scripts/geometry.gd")
const Machinery = preload("res://scripts/machinery.gd")
const Explorer = preload("res://scripts/player.gd")
const Interface = preload("res://scripts/interface.gd")
const Ambience = preload("res://scripts/ambience.gd")

var mat: Dictionary
var kit: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var ambience: Node
var environment: Environment
var doors: Array[Dictionary] = []
var interactables: Array[Node3D] = []
var light_sources: Array[Dictionary] = []
var elapsed := 0.0
var zone_name := ""
var hover: Node3D
var dust: GPUParticles3D
var room_bounds := [
	{"name": "COMMAND BRIDGE", "detail": "01 / NAVIGATION", "rect": Rect2(-10, -46, 20, 18)},
	{"name": "ENGINE CATHEDRAL", "detail": "02 / PROPULSION", "rect": Rect2(-19, -12, 15.4, 25)},
	{"name": "CARGO HOLD", "detail": "03 / LOGISTICS", "rect": Rect2(3.6, -6, 17.4, 26)},
	{"name": "MACHINE SHOP", "detail": "04 / MAINTENANCE", "rect": Rect2(-16, 18, 12.4, 14)},
	{"name": "OBSERVATION", "detail": "05 / EXTERNAL WATCH", "rect": Rect2(3.6, -25, 11.4, 12)},
	{"name": "AFT AIRLOCK", "detail": "06 / ACCESS", "rect": Rect2(-6, 32, 12, 8)},
	{"name": "CENTRAL SPINE", "detail": "DECK 01 / HABITABLE SECTION", "rect": Rect2(-3.6, -28, 7.2, 60)}
]

func _ready() -> void:
	mat = MaterialLibrary.build()
	_build_environment()
	kit = Machinery.new()
	add_child(kit)
	kit.configure(mat)
	_build_spine()
	_build_bridge()
	_build_engine_room()
	_build_cargo()
	_build_workshop()
	_build_observation()
	_build_airlock()
	_detail_pass()
	_build_player()
	_build_dust()
	if OS.get_cmdline_user_args().has("--smoke-test"):
		_run_smoke_test.call_deferred()
	if OS.get_cmdline_user_args().has("--capture-tour"):
		_capture_tour.call_deferred()

func _exit_tree() -> void:
	Geometry.clear_cache()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("799eaa")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.25
	environment.fog_enabled = true
	environment.fog_light_color = Color("223638")
	environment.fog_light_energy = 0.35
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.0
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.ssao_enabled = forward
	environment.ssao_radius = 1.8
	environment.ssao_intensity = 2.1
	environment.ssil_enabled = forward
	environment.ssil_intensity = 1.2
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_bloom = 0.12
	environment.volumetric_fog_enabled = forward
	environment.volumetric_fog_density = 0.014
	environment.volumetric_fog_albedo = Color("6d8584")
	environment.volumetric_fog_emission = Color("172126")
	environment.volumetric_fog_emission_energy = 0.15
	world_environment.environment = environment
	add_child(world_environment)

func _build_spine() -> void:
	_floor(Rect2(-3.6, -28, 7.2, 60))
	_box("Spine ceiling", Vector3(0, 5, 2), Vector3(7.6, 0.3, 60), "ceiling")
	_wall_x(-3.7, -28, 32, 5, [Vector2(-2.1, 2.1), Vector2(22.9, 27.1)])
	_wall_x(3.7, -28, 32, 5, [Vector2(4.9, 9.1), Vector2(-21.1, -16.9)])
	for z in range(-26, 33, 5):
		_arch(float(z), 3.5, 4.8)
		for side in [-1.0, 1.0]:
			for i in 3:
				_pipe(Vector3(side * (2.65 + i * 0.29), 4.25, z - 2.5), Vector3(side * (2.65 + i * 0.29), 4.25, z + 2.5), 0.085 + i * 0.015, "copper" if i == 0 else "iron")
			_box("Cable tray", Vector3(side * 2.7, 3.62, z), Vector3(0.9, 0.10, 4.9), "dark", false)
			for j in 7:
				_box("Tray rib", Vector3(side * 2.7, 3.67, z - 2.2 + j * 0.7), Vector3(0.92, 0.07, 0.07), "steel", false)
			_fixture(Vector3(side * 3.4, 2.65, z + 1.0), Color("f6b770") if z % 2 == 0 else Color("91c8ca"), 2.0, 7.0)
			_box("Low guide", Vector3(side * 3.42, 0.3, z), Vector3(0.06, 0.06, 2.8), "glow_amber", false)
		_box("Central floor inset", Vector3(0, 0.008, z), Vector3(2.3, 0.025, 4.8), "dark", false)
		for x in [-1.22, 1.22]:
			_box("Deck lane", Vector3(x, 0.026, z), Vector3(0.045, 0.016, 4.75), "brass", false)
		for k in range(12):
			_box("Floor grate crossbar", Vector3(0, 0.03, z - 2.1 + k * 0.37), Vector3(2.25, 0.045, 0.075), "iron", false)
	_door(Vector3(-3.65, 0, 0), "02", "ENGINE CATHEDRAL", true)
	_door(Vector3(3.65, 0, 7), "03", "CARGO HOLD", true)
	_door(Vector3(-3.65, 0, 25), "04", "MACHINE SHOP", true)
	_door(Vector3(3.65, 0, -19), "05", "OBSERVATION", true)
	_sign("FORWARD   /   COMMAND", Vector3(0, 3.82, -25.2), 0, 35, Color("d8c394"))
	_sign("N O C T U R N E", Vector3(0, 3.72, 20), 0, 30, Color("8ab1b4"))
	_sign("DECK 01    —    PRESSURIZED", Vector3(0, 3.27, 20), 0, 16, Color("b8a781"))
	for z in [-17.0, 13.0]:
		_box("Overhead sign", Vector3(0, 3.85, z), Vector3(3.3, 0.85, 0.15), "dark", false)
		_sign("01   BRIDGE   ↑", Vector3(0, 3.88, z + 0.09), 0, 23, Color("b0d8ce"))
		_sign("↓   ENGINEERING   02", Vector3(0, 3.61, z + 0.09), 0, 13, Color("d1b580"))
	for z in [-10.0, 17.0, 29.0]:
		_wall_panel(Vector3(-3.43, 1.6, z), PI / 2)
		_wall_panel(Vector3(3.43, 1.6, z - 2), -PI / 2)

func _build_bridge() -> void:
	_floor(Rect2(-10, -46, 20, 18))
	_box("Bridge ceiling", Vector3(0, 5.9, -37), Vector3(20.4, 0.4, 18.3), "ceiling")
	_wall_z(-28, -10, 10, 5.8, [Vector2(-3.6, 3.6)])
	_wall_x(-10, -46, -28, 5.8, [])
	_wall_x(10, -46, -28, 5.8, [])
	# The forward windows contain only absolute black night.
	_box("Bridge window sill", Vector3(0, 0.68, -46), Vector3(20, 1.36, 0.6), "iron")
	_box("Bridge window header", Vector3(0, 5.47, -46), Vector3(20, 0.85, 0.6), "iron")
	_box("Window safety", Vector3(0, 3.2, -46.25), Vector3(20, 4.1, 0.12), "glass", true)
	for x in [-9.8, -6.5, -3.25, 0, 3.25, 6.5, 9.8]:
		_box("Window mullion", Vector3(x, 3.1, -45.94), Vector3(0.20, 4.3, 0.32), "brass")
		_pipe(Vector3(x, 5.5, -46), Vector3(x * 0.78, 5.5, -29), 0.085, "iron")
	for x in [-7.0, -3.6, 3.6, 7.0]:
		kit.make_console(self, Vector3(x, 0, -42.6), PI)
		_fixture(Vector3(x, 4.9, -42), Color("80c8cf"), 2.7, 8)
	kit.make_console(self, Vector3(-7, 0, -33), -PI / 2)
	kit.make_console(self, Vector3(7, 0, -33), PI / 2)
	# Chart table: opaque printed navigation diagrams, glass cover, brass frame.
	_box("Chart plinth", Vector3(0, 0.55, -35.5), Vector3(2.5, 1.1, 3), "iron")
	_box("Chart table rim", Vector3(0, 1.13, -35.5), Vector3(4.4, 0.18, 3.1), "brass")
	_box("Chart surface", Vector3(0, 1.235, -35.5), Vector3(4.15, 0.035, 2.85), "dark", false)
	for x in range(-8, 9):
		_box("Chart grid", Vector3(x * 0.23, 1.26, -35.5), Vector3(0.012, 0.009, 2.6), "glow_cyan", false)
	for z in range(-5, 6):
		_box("Chart grid", Vector3(0, 1.26, -35.5 + z * 0.23), Vector3(3.8, 0.009, 0.012), "glow_cyan", false)
	_point(Vector3(0, 2.3, -35.5), Color("6babad"), 1.2, 6, false)
	_interaction_note(Vector3(0, 1.4, -34.0), "navigation", "NAVIGATION / SIGNAL LOST\n\nAltitude 1,840 m. Heading 000.\nNo celestial reference detected.\nAutopilot maintains station.\n\nThe windows are not malfunctioning.")
	_sign("N O C T U R N E   /   0 7", Vector3(0, 4.7, -45.7), 0, 37, Color("b6b699"))
	_sign("COMMAND BRIDGE", Vector3(-9.7, 3, -37), PI / 2, 30, Color("d0bc93"))
	for x in [-9.4, 9.4]:
		kit.make_bench(self, Vector3(x, 0, -30.8)).rotation.y = PI / 2
		_fixture(Vector3(x, 3.4, -36), Color("f2ac66"), 3.1, 8)
	for z in [-31.0, -38.0, -44.0]:
		_box("Bridge ceiling crossbeam", Vector3(0, 5.5, z), Vector3(19.6, 0.25, 0.2), "brass", false)

func _build_engine_room() -> void:
	_floor(Rect2(-19, -12, 15.4, 25))
	_box("Engine ceiling", Vector3(-11.3, 7.8, 0.5), Vector3(15.4, 0.3, 25), "ceiling")
	_wall_x(-19, -12, 13, 7.8, [])
	_wall_z(-12, -19, -3.6, 7.8, [])
	_wall_z(13, -19, -3.6, 7.8, [])
	_wall_x(-3.8, -12, 13, 7.8, [Vector2(-2.1, 2.1)])
	kit.make_engine(self, Vector3(-11.5, 0, -4.6))
	kit.make_engine(self, Vector3(-11.5, 0, 6.4))
	for z in [-9.0, -3.0, 3.0, 9.0]:
		_box("Engine rib", Vector3(-11.3, 7.35, z), Vector3(15.3, 0.4, 0.35), "steel")
		for x in [-18.6, -4.0]:
			_box("Engine rib upright", Vector3(x, 3.7, z), Vector3(0.35, 7.4, 0.35), "steel")
		_fixture(Vector3(-18.45, 3.8, z), Color("f6b967"), 5, 10)
		_fixture(Vector3(-4.1, 4.8, z), Color("69c8d4"), 3.5, 10)
		_pipe(Vector3(-17.8, 1.1, z), Vector3(-17.8, 6.9, z), 0.24, "copper")
		_pipe(Vector3(-17.8, 6.9, z), Vector3(-5.0, 6.9, z), 0.24, "copper")
		kit.make_valve(self, Vector3(-17.3, 1.75, z), PI / 2)
	for x in [-16.5, -15.7, -14.9]:
		_pipe(Vector3(x, 6.2, -11.5), Vector3(x, 6.2, 12.5), 0.19, "iron")
	for z in [-10.5, 10.8]:
		kit.make_boiler(self, Vector3(-16, 0, z)).rotation.y = PI if z < 0 else 0.0
		kit.make_console(self, Vector3(-6.3, 0, z), PI / 2)
		kit.make_fan(self, Vector3(-11.5, 5.6, z + (-1 if z < 0 else 1)), PI if z < 0 else 0)
	_sign("02   /   ENGINE CATHEDRAL", Vector3(-11.3, 6.1, -11.75), 0, 42, Color("d9bb78"))
	_sign("LIVE STEAM    •    KEEP CLEAR", Vector3(-11.3, 5.4, -11.75), 0, 20, Color("a66d46"))
	for z in [-4.6, 6.4]:
		for x in [-14.1, -8.9]:
			_box("Engine hazard boundary", Vector3(x, 0.025, z), Vector3(0.36, 0.035, 9.4), "warning", false)
		_point(Vector3(-11.5, 2.8, z), Color("f39549"), 2.2, 7, true)
	_steam(Vector3(-16.9, 4.4, -7.0))
	_steam(Vector3(-8.8, 3.3, 5.5))
	_interaction_note(Vector3(-6.3, 1.6, -9.8), "engine", "ENGINE ROOM / WATCH LOG\n\nTriple-expansion drive: nominal.\nBoiler pressure: 14.8 bar.\nHull vibration: within tolerance.\n\nDo not follow knocking from the pipes.")

func _build_cargo() -> void:
	_floor(Rect2(3.6, -6, 17.4, 26))
	_box("Cargo ceiling", Vector3(12.3, 6.8, 7), Vector3(17.4, 0.35, 26), "ceiling")
	_wall_x(21, -6, 20, 6.8, [])
	_wall_z(-6, 3.6, 21, 6.8, [])
	_wall_z(20, 3.6, 21, 6.8, [])
	_wall_x(3.8, -6, 20, 6.8, [Vector2(4.9, 9.1)])
	for z in [-4.0, 3.0, 10.0, 18.0]:
		_box("Hold truss", Vector3(12.3, 6.3, z), Vector3(17, 0.35, 0.3), "steel")
		for x in [4.2, 20.4]:
			_box("Hold pillar", Vector3(x, 3.2, z), Vector3(0.35, 6.4, 0.4), "steel")
		_fixture(Vector3(12, 5.8, z), Color("b1d3cf"), 4.4, 12)
	for x in [8.0, 12.0, 17.4]:
		for z in [-2.7, 14.5]:
			kit.make_crate(self, Vector3(x, 0, z), Vector3(2.7, 2.1, 2.6))
			if x != 12.0:
				kit.make_crate(self, Vector3(x + 0.12, 2.12, z + 0.06), Vector3(2.25, 1.7, 2.25))
	for z in [3.1, 5.1, 7.1, 9.1]:
		kit.make_tank(self, Vector3(19, 0, z))
		_box("Hold cargo tie", Vector3(18.95, 0.05, z), Vector3(2.2, 0.1, 1.9), "dark", false)
	for x in [7.0, 15.5]:
		_box("Cargo lane paint", Vector3(x, 0.025, 7), Vector3(0.09, 0.02, 22), "brass", false)
	_box("Crane rail", Vector3(13.5, 5.85, 7), Vector3(0.32, 0.5, 24), "warning", false)
	_box("Crane motor", Vector3(13.5, 5.55, 5.5), Vector3(1.1, 0.75, 1.5), "iron", false)
	_pipe(Vector3(13.5, 5.4, 5.5), Vector3(13.5, 3.5, 5.5), 0.035, "steel")
	var hook := TorusMesh.new()
	hook.inner_radius = 0.18
	hook.outer_radius = 0.27
	var hook_node := MeshInstance3D.new()
	hook_node.mesh = hook
	hook_node.material_override = mat.brass
	hook_node.position = Vector3(13.5, 3.3, 5.5)
	hook_node.rotation.x = PI / 2
	add_child(hook_node)
	_sign("03   /   CARGO HOLD", Vector3(12.3, 5.2, -5.75), 0, 46, Color("b6c5b1"))
	_sign("MANIFEST  07—184   /   SEALED FREIGHT", Vector3(12.3, 4.5, -5.75), 0, 20, Color("a78b60"))
	kit.make_console(self, Vector3(5.7, 0, 11.2), -PI / 2)
	_interaction_note(Vector3(6.4, 1.5, 11.2), "manifest", "CARGO MANIFEST / HOLD 03\n\n24 sealed containers.\n12 pressure vessels.\n1 unregistered consignment.\n\nDestination entry has been removed.")
	# Accessible raised inspection gallery with generous steps.
	_box("Gallery deck", Vector3(11.35, 1.45, 18.5), Vector3(13.9, 0.2, 2.5), "floor")
	for i in range(10):
		_box("Gallery stair", Vector3(5.4, (i + 1) * 0.075, 13.6 + i * 0.38), Vector3(1.8, (i + 1) * 0.15, 0.4), "steel", false)
	var ramp := StaticBody3D.new()
	var ramp_collision := CollisionShape3D.new()
	var ramp_shape := ConvexPolygonShape3D.new()
	ramp_shape.points = PackedVector3Array([
		Vector3(4.5, 0, 13.4), Vector3(6.3, 0, 13.4),
		Vector3(4.5, 0, 17.3), Vector3(6.3, 0, 17.3),
		Vector3(4.5, 1.55, 17.3), Vector3(6.3, 1.55, 17.3)])
	ramp_collision.shape = ramp_shape
	ramp.add_child(ramp_collision)
	add_child(ramp)
	kit.make_rail(self, Vector3(8.2, 1.55, 17.15), Vector3(18.3, 1.55, 17.15))
	for x in [8.5, 12.5, 17.5]:
		_box("Gallery support", Vector3(x, 0.7, 18.5), Vector3(0.15, 1.4, 1.8), "iron")

func _build_workshop() -> void:
	_floor(Rect2(-16, 18, 12.4, 14))
	_box("Shop ceiling", Vector3(-9.8, 4.8, 25), Vector3(12.4, 0.25, 14), "ceiling")
	_wall_x(-16, 18, 32, 4.8, [])
	_wall_z(18, -16, -3.6, 4.8, [])
	_wall_z(32, -16, -3.6, 4.8, [])
	_wall_x(-3.8, 18, 32, 4.8, [Vector2(22.9, 27.1)])
	for z in [20.5, 29.3]:
		kit.make_bench(self, Vector3(-12, 0, z))
		kit.make_console(self, Vector3(-6.2, 0, z), PI if z == 20.5 else 0)
		_fixture(Vector3(-10.2, 3.7, z), Color("dfb878"), 4.0, 9)
		for i in range(5):
			_box("Toolboard tool", Vector3(-13.0 + i * 0.5, 1.8, z - 0.5), Vector3(0.09, 0.65 + i * 0.05, 0.12), "brass", false)
	for z in [22.0, 25.0, 28.0]:
		kit.make_tank(self, Vector3(-14.5, 0, z))
		_pipe(Vector3(-15.4, 3.8, z - 1.5), Vector3(-15.4, 3.8, z + 1.5), 0.16, "copper")
	kit.make_crate(self, Vector3(-8, 0, 29.6), Vector3(1.4, 0.7, 1))
	kit.make_fan(self, Vector3(-10, 3.25, 18.3), PI)
	_sign("04   /   MACHINE SHOP", Vector3(-10, 3.8, 18.25), 0, 33, Color("ccb17f"))
	_interaction_note(Vector3(-11.7, 1.2, 21.1), "workshop", "MAINTENANCE / SHIFT 418\n\nPortside lighting circuit repaired.\nObservation shutter remains open.\nReplacement valve sent to engineering.\n\nCrew roster: unavailable.")

func _build_observation() -> void:
	_floor(Rect2(3.6, -25, 11.4, 12))
	_box("Observation ceiling", Vector3(9.3, 5.1, -19), Vector3(11.4, 0.3, 12), "ceiling")
	_wall_z(-25, 3.6, 15, 5, [])
	_wall_z(-13, 3.6, 15, 5, [])
	_wall_x(3.8, -25, -13, 5, [Vector2(-21.1, -16.9)])
	_box("Observation sill", Vector3(15, 0.6, -19), Vector3(0.45, 1.2, 12), "iron")
	_box("Observation header", Vector3(15, 4.6, -19), Vector3(0.45, 0.8, 12), "iron")
	_box("Observation glass", Vector3(15.1, 2.8, -19), Vector3(0.1, 3.2, 12), "glass", true)
	for z in [-24.8, -22, -19, -16, -13.2]:
		_box("Observation mullion", Vector3(14.95, 2.7, z), Vector3(0.4, 3.8, 0.18), "brass")
	for z in [-22.5, -15.5]:
		kit.make_bench(self, Vector3(11.5, 0, z)).rotation.y = PI / 2
		_fixture(Vector3(7, 3.7, z), Color("82b0b7"), 2.7, 8)
	kit.make_console(self, Vector3(6, 0, -23), PI)
	_sign("05   /   OBSERVATION", Vector3(9.3, 3.7, -24.75), 0, 31, Color("85aeb1"))
	_sign("EXTERNAL VISIBILITY: ZERO", Vector3(9.3, 3.2, -24.75), 0, 18, Color("b69768"))
	_interaction_note(Vector3(6, 1.5, -22.3), "observation", "EXTERNAL WATCH / 03:17\n\nVisibility: 0 m.\nWind speed: 0 knots.\nAmbient noise: none.\n\nThere should be something out there.")

func _build_airlock() -> void:
	_floor(Rect2(-6, 32, 12, 8))
	_box("Aft ceiling", Vector3(0, 4.8, 36), Vector3(12, 0.25, 8), "ceiling")
	_wall_z(32, -6, 6, 4.8, [Vector2(-3.6, 3.6)])
	_wall_z(40, -6, 6, 4.8, [])
	_wall_x(-6, 32, 40, 4.8, [])
	_wall_x(6, 32, 40, 4.8, [])
	_box("Sealed outer hatch", Vector3(0, 1.9, 39.7), Vector3(4.8, 3.8, 0.35), "iron")
	for x in [-2.5, 2.5]:
		_box("Outer hatch frame", Vector3(x, 2, 39.4), Vector3(0.22, 4, 0.4), "warning")
		_fixture(Vector3(x * 1.8, 3.0, 37), Color("c85b43"), 2, 7)
	_sign("EXTERNAL ACCESS", Vector3(0, 3.2, 39.48), PI, 34, Color("d5b394"))
	_sign("SEALED  /  PRESSURE LOCK", Vector3(0, 2.65, 39.48), PI, 20, Color("cc7350"))
	kit.make_valve(self, Vector3(0, 1.65, 39.35), 0)
	for x in [-4.3, 4.3]:
		kit.make_tank(self, Vector3(x, 0, 34))
	_interaction_note(Vector3(2.9, 1.5, 39.3), "airlock", "AFT AIRLOCK / INTERLOCK ENGAGED\n\nExterior access is disabled.\nInternal pressure: stable.\n\nThis vessel is your entire world.")

func _build_player() -> void:
	player = Explorer.new()
	player.name = "Explorer"
	player.position = Vector3(0, 0.15, 23)
	add_child(player)
	player.interact_requested.connect(_interact)
	ui = Interface.new()
	ui.player = player
	ui.deck_rooms = room_bounds
	add_child(ui)
	ui.quality_changed.connect(_set_quality)
	ambience = Ambience.new()
	ambience.player = player
	add_child(ambience)
	ui.master_volume_changed.connect(func(value: float): ambience.master_gain = value)

func _floor(rect: Rect2) -> void:
	var center := rect.get_center()
	_box("Pressure deck", Vector3(center.x, -0.2, center.y), Vector3(rect.size.x, 0.4, rect.size.y), "floor")
	# Recessed seams give the large deck a human-scale panel rhythm.
	var x := rect.position.x + 2.4
	while x < rect.end.x:
		_box("Deck seam", Vector3(x, 0.006, center.y), Vector3(0.026, 0.012, rect.size.y), "dark", false)
		x += 2.4
	var z := rect.position.y + 2.4
	while z < rect.end.y:
		_box("Deck seam", Vector3(center.x, 0.006, z), Vector3(rect.size.x, 0.012, 0.026), "dark", false)
		z += 2.4

func _wall_x(x: float, z_start: float, z_end: float, height: float, openings: Array) -> void:
	var current := z_start
	openings.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	for opening: Vector2 in openings:
		_wall_panel_run(Vector3(x, height / 2, (current + opening.x) / 2), Vector3(0.26, height, opening.x - current))
		_box("Bulkhead lintel", Vector3(x, (height + 3.4) / 2, opening.x + (opening.y - opening.x) / 2), Vector3(0.32, height - 3.4, opening.y - opening.x), "wall")
		current = opening.y
	_wall_panel_run(Vector3(x, height / 2, (current + z_end) / 2), Vector3(0.26, height, z_end - current))

func _wall_z(z: float, x_start: float, x_end: float, height: float, openings: Array) -> void:
	var current := x_start
	for opening: Vector2 in openings:
		_wall_panel_run(Vector3((current + opening.x) / 2, height / 2, z), Vector3(opening.x - current, height, 0.26))
		_box("Bulkhead lintel", Vector3((opening.x + opening.y) / 2, (height + 3.4) / 2, z), Vector3(opening.y - opening.x, height - 3.4, 0.3), "wall")
		current = opening.y
	_wall_panel_run(Vector3((current + x_end) / 2, height / 2, z), Vector3(x_end - current, height, 0.26))

func _wall_panel_run(pos: Vector3, size: Vector3) -> void:
	if size.x < 0.01 or size.z < 0.01:
		return
	_box("Hull panel", pos, size, "wall")
	var along_x := size.x > size.z
	var length := size.x if along_x else size.z
	var count := maxi(1, int(ceil(length / 2.4)))
	for i in range(count + 1):
		var offset := -length / 2 + float(i) * length / count
		var rib_pos := pos + (Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset))
		_box("Panel stiffener", rib_pos, Vector3(0.10, size.y, 0.36) if along_x else Vector3(0.36, size.y, 0.10), "steel", false)
	for y in [0.23, 1.05, size.y - 0.28]:
		_box("Hull horizontal trim", Vector3(pos.x, y, pos.z), Vector3(size.x, 0.10, 0.34) if along_x else Vector3(0.34, 0.10, size.z), "iron", false)

func _arch(z: float, width: float, height: float) -> void:
	for side in [-1.0, 1.0]:
		_box("Frame upright", Vector3(side * width, height / 2, z), Vector3(0.22, height, 0.3), "steel")
		var brace := _box("Frame corner", Vector3(side * (width - 0.42), height - 0.38, z), Vector3(1.1, 0.25, 0.32), "steel", false)
		brace.rotation.z = side * PI / 4
		for y in [0.4, 1.3, 2.2, 3.1]:
			_box("Frame fastener", Vector3(side * (width - 0.125), y, z + 0.17), Vector3(0.06, 0.07, 0.055), "brass", false)
	_box("Frame header", Vector3(0, height, z), Vector3(width * 2, 0.25, 0.3), "steel")
	_box("Roof center strip", Vector3(0, height - 0.16, z), Vector3(1.25, 0.07, 0.15), "glow_cyan", false)

func _door(pos: Vector3, number: String, title: String, side_wall: bool) -> void:
	var root := Node3D.new()
	root.name = title.replace(" ", "") + "Bulkhead"
	add_child(root)
	root.position = pos
	if side_wall:
		root.rotation.y = PI / 2
	var door := {"root": root, "open": false, "amount": 0.0, "panels": [], "title": title}
	for side in [-1.0, 1.0]:
		_local_box(root, Vector3(side * 2.18, 1.7, 0), Vector3(0.25, 3.4, 0.65), "steel", true)
		_local_box(root, Vector3(side * 2.0, 1.7, 0.34), Vector3(0.08, 3.2, 0.04), "warning", false)
		var panel := Node3D.new()
		root.add_child(panel)
		panel.position = Vector3(side * 1.0, 0, 0)
		panel.set_meta("side", side)
		var leaf := _local_box(panel, Vector3(0, 1.6, 0), Vector3(1.98, 3.2, 0.22), "iron", true)
		leaf.set_meta("door_index", doors.size())
		for y in [0.4, 1.2, 2.2, 2.85]:
			_local_box(panel, Vector3(0, y, 0), Vector3(1.8, 0.08, 0.30), "steel", false)
		_local_box(panel, Vector3(0, 1.95, 0), Vector3(1.25, 0.46, 0.27), "dark", false)
		_local_box(panel, Vector3(side * -0.8, 1.6, 0), Vector3(0.055, 2.7, 0.26), "brass", false)
		door.panels.append(panel)
	_local_box(root, Vector3(0, 3.45, 0), Vector3(4.6, 0.4, 0.65), "steel", true)
	_local_box(root, Vector3(0, 0.025, 0), Vector3(4.2, 0.05, 0.6), "warning", false)
	for facing in [-1.0, 1.0]:
		var label := _sign(number + "  /  " + title, Vector3(0, 3.7, facing * 0.36), 0 if facing > 0 else PI, 21, Color("d1c39f"), root)
		label.outline_size = 1
		var panel := _local_box(root, Vector3(2.55, 1.4, facing * 0.26), Vector3(0.36, 0.6, 0.2), "dark", true)
		panel.set_meta("door_index", doors.size())
		_local_box(root, Vector3(2.55, 1.47, facing * 0.38), Vector3(0.19, 0.22, 0.04), "glow_cyan", false)
		_local_box(root, Vector3(0, 3.37, facing * 0.36), Vector3(0.8, 0.06, 0.035), "glow_amber", false)
	doors.append(door)

func _wall_panel(pos: Vector3, angle: float) -> void:
	var panel := Node3D.new()
	add_child(panel)
	panel.position = pos
	panel.rotation.y = angle
	_local_box(panel, Vector3.ZERO, Vector3(1.3, 1.7, 0.15), "iron", false)
	for y in range(8):
		_local_box(panel, Vector3(0, -0.45 + y * 0.13, 0.1), Vector3(0.9, 0.04, 0.06), "dark", false)
	_local_box(panel, Vector3(0.43, 0.65, 0.13), Vector3(0.09, 0.09, 0.06), "glow_amber", false)
	_sign("HV / 440", Vector3(-0.1, 0.65, 0.1), 0, 12, Color("bdab88"), panel)

func _fixture(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	_box("Lamp housing", pos, Vector3(0.42, 0.66, 0.28), "dark", false)
	_box("Lamp diffuser", pos + Vector3(0, 0, 0.03), Vector3(0.22, 0.44, 0.3), "glow_amber" if color.r > color.b else "glow_cyan", false)
	for y in [-0.2, 0, 0.2]:
		_box("Lamp cage", pos + Vector3(0, y, 0), Vector3(0.38, 0.035, 0.37), "iron", false)
	_point(pos + Vector3(0, -0.1, 0.35), color, energy, radius, false)

func _point(pos: Vector3, color: Color, energy: float, radius: float, shadows: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.25
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 0.45
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24
	light.distance_fade_length = 12
	add_child(light)
	light_sources.append({"light": light, "energy": energy, "phase": light_sources.size() * 1.92})
	return light

func _box(title: String, pos: Vector3, size: Vector3, material: String, collision := true) -> Node3D:
	var result := _local_box(self, pos, size, material, collision)
	result.name = title
	return result

func _local_box(parent: Node3D, pos: Vector3, size: Vector3, material: String, collision: bool) -> Node3D:
	var mesh: Mesh
	if minf(size.x, minf(size.y, size.z)) > 0.12:
		mesh = Geometry.beveled_box(size, 0.025)
	else:
		var simple := BoxMesh.new()
		simple.size = size
		mesh = simple
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat[material]
	var result: Node3D
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		body.add_child(visual)
		result = body
	else:
		result = visual
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	result.position = pos
	return result

func _pipe(a: Vector3, b: Vector3, radius: float, material: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat[material]
	add_child(node)
	node.position = (a + b) * 0.5
	var direction := (b - a).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length() > 0.001:
		node.quaternion = Quaternion(axis.normalized(), acos(Vector3.UP.dot(direction)))
	for at in [a, b]:
		var collar := MeshInstance3D.new()
		var collar_mesh := CylinderMesh.new()
		collar_mesh.top_radius = radius * 1.38
		collar_mesh.bottom_radius = radius * 1.38
		collar_mesh.height = 0.12
		collar_mesh.radial_segments = 12
		collar.mesh = collar_mesh
		collar.material_override = mat.brass
		add_child(collar)
		collar.position = at
		collar.quaternion = node.quaternion

func _sign(text: String, pos: Vector3, angle: float, font_size: int, color: Color, parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 2
	label.outline_modulate = Color("101819")
	label.no_depth_test = false
	parent.add_child(label)
	label.position = pos
	label.rotation.y = angle
	return label

func _interaction_note(pos: Vector3, id: String, content: String) -> void:
	var note := _box("Log terminal", pos, Vector3(0.48, 0.32, 0.16), "screen", true)
	note.set_meta("note", content)
	note.set_meta("note_id", id)
	interactables.append(note)

func _steam(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.position = pos
	particles.amount = 18
	particles.lifetime = 3.0
	particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 7, 6))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.3, 1, 0)
	process.spread = 18
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.75
	process.gravity = Vector3(0, 0.1, 0)
	process.scale_min = 0.18
	process.scale_max = 0.55
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.4, 0.5, 0.48, 0.08))
	gradient.set_color(1, Color(0.4, 0.5, 0.48, 0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	process.color_ramp = texture
	particles.process_material = process
	var puff := QuadMesh.new()
	puff.size = Vector2(2.0, 2.0)
	var steam_mat := ShaderMaterial.new()
	steam_mat.shader = preload("res://shaders/air_particle.gdshader")
	puff.material = steam_mat
	particles.draw_pass_1 = puff
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)

func _build_dust() -> void:
	dust = GPUParticles3D.new()
	dust.amount = 100
	dust.lifetime = 8
	dust.preprocess = 4
	dust.visibility_aabb = AABB(Vector3(-9, -4, -9), Vector3(18, 8, 18))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(7, 2.8, 7)
	process.gravity = Vector3(0, -0.018, 0)
	process.initial_velocity_min = 0.01
	process.initial_velocity_max = 0.045
	process.direction = Vector3.RIGHT
	process.scale_min = 0.008
	process.scale_max = 0.018
	process.color = Color(0.4, 0.6, 0.6, 0.2)
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/air_particle.gdshader")
	quad.material = material
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)

func _detail_pass() -> void:
	# Suspension ribs and service trunks give the rooms a ship-like structure.
	for z in [-9.0, -3.0, 3.0, 9.0]:
		for side in [-1.0, 1.0]:
			var beam := _box("Engine roof knee", Vector3(-11.3 + side * 6.4, 6.5, z), Vector3(2.3, 0.26, 0.34), "steel", false)
			beam.rotation.z = side * PI / 4
			_box("Engine rib gusset", Vector3(-11.3 + side * 7.0, 4.9, z), Vector3(0.5, 0.9, 0.12), "brass", false)
	for z in [-4.0, 3.0, 10.0, 18.0]:
		for side in [-1.0, 1.0]:
			var beam := _box("Hold roof knee", Vector3(12.3 + side * 7, 5.6, z), Vector3(2.6, 0.24, 0.3), "steel", false)
			beam.rotation.z = side * PI / 4
	for pos in [Vector3(-11.3, 7.1, -6), Vector3(-11.3, 7.1, 5), Vector3(12.5, 6.1, -1), Vector3(12.5, 6.1, 12)]:
		kit.make_hanging_lamp(self, pos)
		var lamp := SpotLight3D.new()
		lamp.position = pos - Vector3(0, 0.4, 0)
		lamp.rotation_degrees.x = -90
		lamp.light_color = Color("e8bc82")
		lamp.light_energy = 4.8
		lamp.spot_range = 13
		lamp.spot_angle = 56
		lamp.spot_attenuation = 0.8
		lamp.shadow_enabled = true
		lamp.light_volumetric_fog_energy = 1.0
		add_child(lamp)
	for x in [-7.0, -3.6, 3.6, 7.0]:
		_chair(Vector3(x, 0, -40.9), 0)
	# Raised circular compass rose under the navigation table.
	for radius in [2.6, 2.75, 3.0]:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius - 0.013
		mesh.outer_radius = radius + 0.013
		mesh.rings = 96
		mesh.ring_segments = 6
		ring.mesh = mesh
		ring.material_override = mat.brass
		ring.position = Vector3(0, 0.03, -35.5)
		add_child(ring)
	for x in [-8.8, 8.8]:
		kit.make_terminal(self, Vector3(x, 0, -38), PI / 2 if x > 0 else -PI / 2)
	kit.make_terminal(self, Vector3(-4.5, 0, 6), PI / 2)
	# Port service line: uneven cable runs and pipe supports.
	for z in [-22.0, -12.0, 8.0, 18.0, 28.0]:
		for cable in 3:
			for segment in 8:
				var t := float(segment) / 8.0
				var u := float(segment + 1) / 8.0
				var a := Vector3(-3.29 + cable * 0.045, 3.3 - sin(t * PI) * 0.22, z + t * 3.6)
				var b := Vector3(-3.29 + cable * 0.045, 3.3 - sin(u * PI) * 0.22, z + u * 3.6)
				_pipe(a, b, 0.018, "rubber")
	for z in [-20.0, -5.0, 10.0, 25.0]:
		var label := _sign("↑  01  /  COMMAND", Vector3(0, 0.065, z), 0, 28, Color("77796a"))
		label.rotation.x = -PI / 2
		label.pixel_size = 0.008
	# Riveted cover plates catch grazing light on the otherwise dark hull.
	for z in range(-25, 32, 5):
		for side in [-1.0, 1.0]:
			for y in [0.55, 2.05, 3.45]:
				var plate := _box("Hull junction plate", Vector3(side * 3.48, y, z + 0.45), Vector3(0.045, 0.32, 0.3), "iron", false)
				for dy in [-0.105, 0.105]:
					for dz in [-0.095, 0.095]:
						_box("Plate rivet", plate.position + Vector3(-side * 0.028, dy, dz), Vector3(0.025, 0.028, 0.028), "brass", false)
	for z in [-40.0, -31.5]:
		_box("Bridge ventilation trunk", Vector3(0, 5.45, z), Vector3(18, 0.35, 0.7), "iron", false)
		for x in range(-8, 9):
			_box("Vent slot", Vector3(x, 5.23, z), Vector3(0.65, 0.04, 0.5), "dark", false)
	# Small human traces, with no crew or player model.
	for pos in [Vector3(-12.5, 0.94, 20.4), Vector3(-12.3, 0.94, 29.3)]:
		_box("Maintenance notebook", pos, Vector3(0.32, 0.035, 0.42), "paint", false)
		_box("Notebook spine", pos + Vector3(-0.14, 0.025, 0), Vector3(0.035, 0.02, 0.42), "dark", false)
		_pipe(pos + Vector3(0.29, 0.07, 0), pos + Vector3(0.29, 0.23, 0), 0.065, "steel")
	# Maintenance trolley and wall storage.
	var cart := Vector3(-10.6, 0, 26)
	_box("Tool trolley", cart + Vector3(0, 0.65, 0), Vector3(1.2, 1, 0.65), "red")
	for y in [0.32, 0.55, 0.78, 1.01]:
		_box("Tool drawer", cart + Vector3(0, y, 0.34), Vector3(1.05, 0.17, 0.045), "iron", false)
		_box("Drawer handle", cart + Vector3(0, y, 0.39), Vector3(0.4, 0.04, 0.06), "steel", false)
	for x in [-0.45, 0.45]:
		for z in [-0.22, 0.22]:
			_pipe(cart + Vector3(x, 0.14, z - 0.04), cart + Vector3(x, 0.14, z + 0.04), 0.13, "rubber")
	for z in [21, 24, 27, 30]:
		_box("Shop ceiling beam", Vector3(-9.8, 4.5, z), Vector3(12, 0.2, 0.25), "iron", false)
	# Piping beneath the bridge windows and observation handrail.
	for y in [0.45, 0.8]:
		_pipe(Vector3(-9.5, y, -45.4), Vector3(9.5, y, -45.4), 0.07, "copper")
	kit.make_rail(self, Vector3(14.2, 0, -24.2), Vector3(14.2, 0, -13.8))

func _chair(pos: Vector3, angle: float) -> void:
	var chair := Node3D.new()
	add_child(chair)
	chair.position = pos
	chair.rotation.y = angle
	_local_box(chair, Vector3(0, 0.08, 0), Vector3(0.7, 0.16, 0.7), "iron", false)
	_local_box(chair, Vector3(0, 0.39, 0), Vector3(0.18, 0.6, 0.18), "steel", true)
	_local_box(chair, Vector3(0, 0.72, 0), Vector3(0.78, 0.18, 0.75), "rubber", true)
	_local_box(chair, Vector3(0, 1.14, 0.34), Vector3(0.74, 0.82, 0.13), "rubber", true)
	for x in [-0.43, 0.43]:
		_local_box(chair, Vector3(x, 0.88, 0.13), Vector3(0.055, 0.45, 0.06), "brass", false)
		_local_box(chair, Vector3(x, 1.04, -0.03), Vector3(0.12, 0.08, 0.6), "dark", false)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	elapsed += delta
	dust.position = player.position + Vector3(0, 2, 0)
	for door in doors:
		# Closing is inhibited when the player occupies the doorway.
		if not door.open and door.amount > 0.02 and player.global_position.distance_to(door.root.global_position) < 2.4:
			door.open = true
		door.amount = move_toward(door.amount, 1.0 if door.open else 0.0, delta * 0.8)
		for panel: Node3D in door.panels:
			panel.position.x = float(panel.get_meta("side")) * (1 + smoothstep(0.0, 1.0, door.amount) * 2.05)
	for source in light_sources:
		var pulse := sin(elapsed * 1.7 + source.phase) * 0.025 + sin(elapsed * 7.3 + source.phase) * 0.009
		source.light.light_energy = source.energy * (1 + pulse)
	_update_zone()
	_update_hover()

func _update_zone() -> void:
	var point := Vector2(player.position.x, player.position.z)
	for room in room_bounds:
		if room.rect.has_point(point):
			if room.name != zone_name:
				zone_name = room.name
				ui.set_zone(room.name, room.detail)
				ambience.set_zone(room.name)
			return

func _update_hover() -> void:
	hover = null
	if not player.active:
		ui.set_interaction("")
		return
	var origin: Vector3 = player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin, origin - player.camera.global_basis.z * 3.2)
	ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var object: Node = hit.collider
		if object.has_meta("door_index"):
			hover = object
			var door: Dictionary = doors[int(object.get_meta("door_index"))]
			ui.set_interaction(("CLOSE  /  " if door.open else "OPEN  /  ") + door.title)
			return
		if object.has_meta("note"):
			hover = object
			ui.set_interaction("READ SHIP LOG")
			return
	ui.set_interaction("")

func _interact(_origin: Vector3, _direction: Vector3) -> void:
	if not is_instance_valid(hover):
		return
	if hover.has_meta("door_index"):
		var door: Dictionary = doors[int(hover.get_meta("door_index"))]
		door.open = not door.open
		if ambience.has_method("play_door"):
			ambience.play_door()
	elif hover.has_meta("note"):
		ui.notify(str(hover.get_meta("note")))

func _set_quality(high: bool) -> void:
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.ssao_enabled = high and forward
	environment.ssil_enabled = high and forward
	environment.volumetric_fog_enabled = high and forward
	get_viewport().msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_DISABLED
	dust.amount = 100 if high else 35

func _run_smoke_test() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var errors: Array[String] = []
	for room in room_bounds:
		var point: Vector2 = room.rect.get_center()
		var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x, 0.4, point.y), Vector3(point.x, -0.8, point.y))
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			errors.append("Missing floor: " + room.name)
	for door in doors:
		door.open = true
	await get_tree().create_timer(1.6).timeout
	for door in doors:
		if door.amount < 0.99:
			errors.append("Door did not open: " + door.title)
	print("SMOKE: rooms=%d doors=%d terminals=%d lights=%d" % [room_bounds.size(), doors.size(), interactables.size(), light_sources.size()])
	if errors.is_empty():
		print("SMOKE PASS: all seven rooms have collision floors; all four bulkheads open.")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error(error)
		get_tree().quit(1)

func _capture_tour() -> void:
	ui.hide()
	player.set_control_enabled(false)
	player.set_physics_process(false)
	for door in doors:
		door.open = true
	var views := [
		["01_spine", Vector3(0, 1.85, 22), Vector3(0, 2.2, -20)],
		["02_engine", Vector3(-5.4, 2.5, 10.6), Vector3(-12, 2.6, -5)],
		["03_bridge", Vector3(0, 2.3, -29), Vector3(0, 2.0, -44)],
		["04_cargo", Vector3(5.0, 2.0, 9), Vector3(14, 2.2, 1)],
		["05_workshop", Vector3(-5.2, 2.0, 26.5), Vector3(-12, 1.7, 22)]
	]
	DirAccess.make_dir_recursive_absolute("res://captures")
	for view in views:
		player.camera.global_position = view[1]
		player.camera.look_at(view[2])
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/" + view[0] + ".png")
		print("CAPTURE " + view[0])
	get_tree().quit()
