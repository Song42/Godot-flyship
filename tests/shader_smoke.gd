extends SceneTree
## Standalone renderer smoke test for the original material library.
## godot --path . --script tests/shader_smoke.gd --rendering-method gl_compatibility

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var materials: Dictionary = load("res://scripts/materials.gd").build()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.07, 0.08, 0.09)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.55, 0.62, 0.65)
	world.environment.ambient_light_energy = 0.65
	scene.add_child(world)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 4, 8)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 2.5
	var index := 0
	for key in materials:
		var instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.85, 0.65, 0.85)
		instance.mesh = mesh
		instance.material_override = materials[key]
		scene.add_child(instance)
		instance.position = Vector3(float(index % 6) - 2.5, 0, float(index / 6) - 1.5)
		index += 1
	for frame in range(20):
		await process_frame
	print("MATERIAL_SMOKE_OK: ", materials.size(), " surfaces")
	if not DisplayServer.get_name() == "headless":
		DirAccess.make_dir_recursive_absolute("res://.tools")
		viewport.get_texture().get_image().save_png("res://.tools/material-preview.png")
	quit()
