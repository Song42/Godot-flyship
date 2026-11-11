extends "res://scripts/ship_architecture.gd"
## A cramped timber gondola beneath a canvas envelope. Bow is -Z; deck is y=0.

const MaterialLibrary = preload("res://scripts/materials.gd")
const Interior = preload("res://scripts/interior_layout.gd")
const Machinery = preload("res://scripts/machinery.gd")
const Furnishings = preload("res://scripts/furnishings.gd")
const Explorer = preload("res://scripts/player.gd")
const Interface = preload("res://scripts/interface.gd")
const Ambience = preload("res://scripts/ambience.gd")

var player: CharacterBody3D
var ui: CanvasLayer
var ambience: Node
var environment: Environment
var elapsed := 0.0
var zone_name := ""
var hover: Node3D
var dust: GPUParticles3D
var propellers: Array[Node3D] = []
var room_bounds := [
	{"name":"WHEELHOUSE", "detail":"01 / THE HELM", "rect":Rect2(-3.4,-23,6.8,5)},
	{"name":"CHART ROOM", "detail":"02 / NAVIGATION", "rect":Rect2(-3.4,-18,6.8,6)},
	{"name":"CREW QUARTERS", "detail":"03 / FOUR BERTHS PER CABIN", "rect":Rect2(-5.6,-12,4.7,8)},
	{"name":"CAPTAIN'S CABIN", "detail":"04 / PRIVATE QUARTERS", "rect":Rect2(-5.6,-4,4.7,7)},
	{"name":"MESS ROOM", "detail":"05 / THE LONG TABLE", "rect":Rect2(0.9,-12,4.9,9)},
	{"name":"GALLEY", "detail":"06 / SHIP'S KITCHEN", "rect":Rect2(0.9,-3,4.9,9)},
	{"name":"ENGINE ROOM", "detail":"07 / LIVE STEAM", "rect":Rect2(-6,3,5.1,9)},
	{"name":"WORKSHOP", "detail":"08 / CARPENTER & ENGINEER", "rect":Rect2(-5.6,12,4.7,5)},
	{"name":"CARGO HOLD", "detail":"09 / STORES & PROVISIONS", "rect":Rect2(0.9,6,4.9,11)},
	{"name":"PASSAGE", "detail":"LOWER DECK / MIND YOUR HEAD", "rect":Rect2(-0.9,-12,1.8,29)},
	{"name":"FOREDECK", "detail":"OPEN AIR / NO STARS TONIGHT", "rect":Rect2(-5.8,-28,11.6,5)},
	{"name":"PORT WALKWAY", "detail":"OUTSIDE / PORT SIDE", "rect":Rect2(-5.8,-23,2.4,11)},
	{"name":"STARBOARD WALKWAY", "detail":"OUTSIDE / STARBOARD SIDE", "rect":Rect2(3.4,-23,2.4,11)},
	{"name":"BALCONY", "detail":"OUTSIDE / THE TIMBER PROMENADE", "rect":Rect2(5.8,-14,2.1,31)}
]

func _ready() -> void:
	mat=MaterialLibrary.build()
	_build_environment()
	kit=Machinery.new()
	add_child(kit)
	kit.configure(mat)
	furniture=Furnishings.new()
	add_child(furniture)
	furniture.configure(mat)
	_build_passage()
	Interior.build(self)
	_build_exterior()
	_build_player()
	_build_dust()
	if OS.get_cmdline_user_args().has("--smoke-test"):_run_smoke_test.call_deferred()
	if OS.get_cmdline_user_args().has("--capture-tour"):_capture_tour.call_deferred()

func _exit_tree() -> void:
	preload("res://scripts/geometry.gd").clear_cache()

func _build_environment() -> void:
	var holder:=WorldEnvironment.new()
	environment=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color.BLACK
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("a8abb3")
	environment.ambient_light_energy=0.42
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=1.16
	environment.fog_enabled=true
	environment.fog_light_color=Color("171412")
	environment.fog_light_energy=0.25
	environment.fog_density=0.003
	environment.fog_sky_affect=0.0
	var forward:=RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.ssao_enabled=forward
	environment.ssao_radius=0.75
	environment.ssao_intensity=1.15
	environment.ssil_enabled=forward
	environment.ssil_intensity=0.8
	environment.glow_enabled=true
	environment.glow_intensity=0.22
	environment.glow_bloom=0.025
	environment.volumetric_fog_enabled=forward
	environment.volumetric_fog_density=0.006
	environment.volumetric_fog_albedo=Color("8b7e68")
	environment.volumetric_fog_emission_energy=0.0
	holder.environment=environment
	add_child(holder)

func _build_passage() -> void:
	_floor(Rect2(-0.9,-12,1.8,29))
	_box("Low timber ceiling",Vector3(0,2.72,2.5),Vector3(1.95,0.18,29),"ceiling")
	_wall_x(-0.96,-12,17,2.65,[_opening(-10),_opening(-6),_opening(0),_opening(7),_opening(14.5)])
	_wall_x(0.96,-12,17,2.65,[_opening(-8),_opening(2),_opening(12)])
	_wall_z(17,-0.9,0.9,2.65,[])
	for z in range(-11,18,2):
		_arch(float(z),1.8,2.53)
		for side in [-1.0,1.0]:
			_pipe(Vector3(side*0.66,2.36,z-1),Vector3(side*0.66,2.36,z+1),0.055,"copper")
			_pipe(Vector3(side*0.78,2.22,z-1),Vector3(side*0.78,2.22,z+1),0.034,"iron")
	for z in [-10.7,-5.1,0.7,6.2,11.1,15.5]:_lantern(Vector3(0,2.35,z),1.6,4.4)
	for spec in [[-10.0,"03A","CREW / A"],[-6.0,"03B","CREW / B"],[0.0,"04","CAPTAIN"],[7.0,"07","ENGINE ROOM"],[14.5,"08","WORKSHOP"]]:
		_door(Vector3(-0.96,0,spec[0]),spec[1],spec[2],true)
	for spec in [[-8.0,"05","MESS ROOM"],[2.0,"06","GALLEY"],[12.0,"09","CARGO HOLD"]]:
		_door(Vector3(0.96,0,spec[0]),spec[1],spec[2],true)
	for z in [-3.2,9.5]:
		_box("Service cupboard",Vector3(-0.66,1.15,z),Vector3(0.34,2.25,0.7),"wood_dark")
		_box("Cupboard handle",Vector3(-0.46,1.05,z),Vector3(0.04,0.18,0.04),"brass",false)
		_sign("OIL / TOOLS",Vector3(-0.47,1.58,z),PI/2,12,0.0035)
	_sign("N O C T U R N E",Vector3(0,2.25,13.9),0,23,0.005)
	_sign("FORWARD / THE HELM",Vector3(0,2.29,-11.8),0,16,0.0045)
	_note(Vector3(0.68,1.45,16.4),"WELCOME ABOARD\n\nNocturne, launched 1886.\nKeep the galley stove banked.\nThe promenade joins the mess and cargo hold.\n\nThere are no stars tonight.",-PI/2)

func _build_exterior() -> void:
	_floor(Rect2(-5.8,-28,11.6,5))
	_floor(Rect2(-5.8,-23,2.4,11))
	_floor(Rect2(3.4,-23,2.4,11))
	_floor(Rect2(5.8,-14,2.1,31))
	_rail(Vector3(-5.7,0,-27.9),Vector3(5.7,0,-27.9))
	_rail(Vector3(-5.7,0,-27.9),Vector3(-5.7,0,-12.1))
	_rail(Vector3(5.7,0,-27.9),Vector3(5.7,0,-14.1))
	_rail(Vector3(-5.7,0,-12.1),Vector3(-3.4,0,-12.1))
	_rail(Vector3(7.8,0,-13.9),Vector3(7.8,0,16.9))
	_rail(Vector3(5.8,0,-13.9),Vector3(7.8,0,-13.9))
	_rail(Vector3(5.8,0,16.9),Vector3(7.8,0,16.9))
	for z in [-25.2,-19.5,-13.0,-6.0,1.0,8.0,15.6]:
		var x:=7.5 if z>-14 else 5.4
		_box("Lantern post",Vector3(x,1.13,z),Vector3(0.11,2.26,0.11),"wood_dark")
		_lantern(Vector3(x,2.13,z),2.0,5.8)
		if z < -12:
			_box("Lantern post",Vector3(-5.4,1.13,z),Vector3(0.11,2.26,0.11),"wood_dark")
			_lantern(Vector3(-5.4,2.13,z),2.0,5.8)
	furniture.chair(self,Vector3(6.15,0,-3.1),-PI/2)
	furniture.barrel(self,Vector3(6.18,0,-1.8)).scale=Vector3(0.7,0.68,0.7)
	for z in [-24.7,-21.0]:furniture.barrel(self,Vector3(-4.95,0,z))
	_box("Mooring winch",Vector3(0,0.3,-26.2),Vector3(1.5,0.6,0.7),"wood_dark")
	_pipe(Vector3(-0.8,0.8,-26.2),Vector3(0.8,0.8,-26.2),0.22,"wood")
	for i in 8:_ring(Vector3(-0.4+i*0.11,0.8,-26.2),0.23,0.035,"rope",0,PI/2)
	for i in 4:_ring(Vector3(1.7,0.04+i*0.025,-26.3),0.38+i*0.04,0.022,"rope")
	_build_hull_and_envelope()
	# Outboard airscrews sit outside the walking balcony, behind a rope guard.
	for side in [-1.0,1.0]:
		var origin:=Vector3(side*9.0,2.1,5.5)
		_pipe(Vector3(side*5.5,1.7,5.5),origin,0.14,"iron")
		var rotor:=Node3D.new()
		add_child(rotor)
		rotor.position=origin
		for i in 4:
			var pivot:=Node3D.new()
			rotor.add_child(pivot)
			_local_box(pivot,Vector3(0,0.75,0),Vector3(0.24,1.5,0.065),"wood_dark",false)
			pivot.rotation.z=i*PI/2
		propellers.append(rotor)
		_ring(origin,1.65,0.045,"iron",PI/2)

func _build_hull_and_envelope() -> void:
	var hull:=SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in 24:
		var z0:float=-28.0+float(section)*45.0/24
		var z1:float=-28.0+float(section+1)*45.0/24
		for edge in 12:
			var a:float=float(edge)*PI/12
			var b:float=float(edge+1)*PI/12
			var p0:=Vector3(cos(a)*5.8,-0.3-sin(a)*2.8,z0)
			var p1:=Vector3(cos(b)*5.8,-0.3-sin(b)*2.8,z0)
			var p2:=Vector3(cos(b)*5.8,-0.3-sin(b)*2.8,z1)
			var p3:=Vector3(cos(a)*5.8,-0.3-sin(a)*2.8,z1)
			for p:Vector3 in [p0,p2,p1,p0,p3,p2]:hull.add_vertex(p)
	hull.generate_normals()
	var hull_mesh:=MeshInstance3D.new()
	hull_mesh.mesh=hull.commit()
	hull_mesh.material_override=mat.wood_dark
	add_child(hull_mesh)
	var bag:=MeshInstance3D.new()
	var envelope:=SphereMesh.new()
	envelope.radius=1.0
	envelope.height=2.0
	envelope.radial_segments=64
	envelope.rings=32
	bag.mesh=envelope
	bag.material_override=mat.canvas
	bag.position=Vector3(0,12,-4)
	bag.scale=Vector3(8.2,5.3,26)
	add_child(bag)
	for z in [-24.0,-18.0,-11.0,-4.0,3.0,10.0,16.0]:
		var longitudinal:float=(z+4.0)/26.0
		var cross_radius:=sqrt(maxf(0.01,1-longitudinal*longitudinal))
		for side in [-1.0,1.0]:
			var anchor:=Vector3(side*6.05,0.3,z)
			_pipe(anchor,Vector3(side*7.0*cross_radius,9.5,z),0.04,"rope")
			_pipe(Vector3(side*3.1,2.9,clampf(z,-22,16)),Vector3(side*5.5*cross_radius,8.1,z),0.055,"iron")
			_box("Rigging shoe",anchor+Vector3(0,0.3,0),Vector3(0.2,0.6,0.2),"iron",false)
		for arc in 32:
			var a:float=float(arc)*TAU/32
			var b:float=float(arc+1)*TAU/32
			_pipe(Vector3(cos(a)*8.24*cross_radius,12+sin(a)*5.34*cross_radius,z),Vector3(cos(b)*8.24*cross_radius,12+sin(b)*5.34*cross_radius,z),0.028,"rope")
	for z in [-20.0,-6.0,9.0]:_point(Vector3(0,5.3,z),Color("c8b394"),1.45,14,false)

func _build_player() -> void:
	player=Explorer.new()
	player.position=Vector3(0,0.15,15.8)
	add_child(player)
	player.interact_requested.connect(_interact)
	ui=Interface.new()
	ui.player=player
	ui.deck_rooms=room_bounds
	add_child(ui)
	ui.quality_changed.connect(_set_quality)
	ambience=Ambience.new()
	ambience.player=player
	add_child(ambience)
	ui.master_volume_changed.connect(func(value:float):ambience.master_gain=value)

func _build_dust() -> void:
	dust=GPUParticles3D.new()
	dust.amount=55
	dust.lifetime=8
	dust.preprocess=3
	dust.visibility_aabb=AABB(Vector3(-5,-3,-5),Vector3(10,6,10))
	var process:=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(4,1.5,4)
	process.gravity=Vector3(0,-0.013,0)
	process.scale_min=0.004
	process.scale_max=0.009
	process.color=Color(0.7,0.61,0.43,0.13)
	dust.process_material=process
	var quad:=QuadMesh.new()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/air_particle.gdshader")
	quad.material=material
	dust.draw_pass_1=quad
	dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)

func _process(delta:float) -> void:
	if not is_instance_valid(player):return
	elapsed+=delta
	dust.position=player.position+Vector3.UP*1.5
	for door:Dictionary in doors:
		if not door.open and door.amount>0.02 and player.global_position.distance_to(door.root.global_position)<1.1:door.open=true
		door.amount=move_toward(door.amount,1.0 if door.open else 0.0,delta*0.9)
		for panel:Node3D in door.panels:panel.position.x=float(panel.get_meta("side"))*(0.35+smoothstep(0.0,1.0,door.amount)*0.73)
	for source:Dictionary in light_sources:source.light.light_energy=source.energy*(1+sin(elapsed*2.1+source.phase)*0.018)
	for rotor:Node3D in propellers:rotor.rotate_z(delta*1.4)
	_update_zone()
	_update_hover()

func _update_zone() -> void:
	var p:=Vector2(player.position.x,player.position.z)
	for room:Dictionary in room_bounds:
		if room.rect.has_point(p):
			if room.name!=zone_name:
				zone_name=room.name
				ui.set_zone(room.name,room.detail)
				ambience.set_zone(room.name)
			return

func _update_hover() -> void:
	hover=null
	if not player.active:
		ui.set_interaction("")
		return
	var origin:Vector3=player.camera.global_position
	var ray:=PhysicsRayQueryParameters3D.create(origin,origin-player.camera.global_basis.z*2.5)
	ray.exclude=[player.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var object:Node=hit.collider
		if object.has_meta("door_index"):
			hover=object
			var door:Dictionary=doors[int(object.get_meta("door_index"))]
			ui.set_interaction(("CLOSE / " if door.open else "OPEN / ")+door.title)
			return
		if object.has_meta("note"):
			hover=object
			ui.set_interaction("READ JOURNAL")
			return
	ui.set_interaction("")

func _interact(_origin:Vector3,_direction:Vector3) -> void:
	if not is_instance_valid(hover):return
	if hover.has_meta("door_index"):
		var door:Dictionary=doors[int(hover.get_meta("door_index"))]
		door.open=not door.open
		ambience.play_door()
	elif hover.has_meta("note"):ui.notify(str(hover.get_meta("note")))

func _set_quality(high:bool) -> void:
	var forward:=RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.ssao_enabled=high and forward
	environment.ssil_enabled=high and forward
	environment.volumetric_fog_enabled=high and forward
	get_viewport().msaa_3d=Viewport.MSAA_4X if high else Viewport.MSAA_2X
	dust.amount=55 if high else 20

func _run_smoke_test() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var errors:Array[String]=[]
	for room:Dictionary in room_bounds:
		var p:Vector2=room.rect.get_center()
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(p.x,0.08,p.y),Vector3(p.x,-0.5,p.y))
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():errors.append("Missing deck: "+room.name)
	for door:Dictionary in doors:door.open=true
	await get_tree().create_timer(1.5).timeout
	for door:Dictionary in doors:
		if door.amount<0.99:errors.append("Door failed: "+door.title)
	print("SMOKE: %d areas / %d doors / %d journals"%[room_bounds.size(),doors.size(),interactables.size()])
	if errors.is_empty():print("SMOKE PASS: timber airship decks and doors.")
	else:
		for error:String in errors:push_error(error)
	get_tree().quit(0 if errors.is_empty() else 1)

func _capture_tour() -> void:
	ui.hide()
	player.set_control_enabled(false)
	player.set_physics_process(false)
	player.flashlight.visible=false
	for door:Dictionary in doors:door.open=true
	var views:=[
		["01_passage",Vector3(0,1.63,12.8),Vector3(0,1.55,-8)],
		["02_crew",Vector3(-1.4,1.55,-10),Vector3(-4.4,1.35,-10)],
		["03_mess",Vector3(1.45,1.65,-10.4),Vector3(3.8,1.25,-6)],
		["04_engine",Vector3(-1.62,1.65,10.5),Vector3(-4,1.25,5.9)],
		["05_balcony",Vector3(7.0,1.7,14.9),Vector3(5.7,4.8,-17)],
		["06_foredeck",Vector3(4.7,1.75,-26.7),Vector3(0,5.7,-10)],
		["07_captain",Vector3(-1.5,1.6,-1.3),Vector3(-4.1,1.15,1)],
		["08_galley",Vector3(2.8,1.6,-2.2),Vector3(4.4,1.2,3.5)]
	]
	DirAccess.make_dir_recursive_absolute("res://captures")
	for view:Array in views:
		player.camera.global_position=view[1]
		player.camera.look_at(view[2])
		await get_tree().create_timer(1.2).timeout
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://captures/"+view[0]+".png")
		print("CAPTURE "+view[0])
	get_tree().quit()
