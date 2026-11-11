extends SceneTree
## Headless integration test: real player motion, bulkhead collision, deck
## connectivity, gallery ascent, hull boundaries and doorway obstruction safety.
## godot --headless --path . --fixed-fps 60 --script tests/traversal.gd

var vessel: Node3D
var explorer: CharacterBody3D
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("TRAVERSAL: " + message)

func _run() -> void:
	vessel = load("res://scenes/main.tscn").instantiate()
	root.add_child(vessel)
	explorer = vessel.player
	vessel.ui.hide()
	await _frames(5)
	# Sweep the player's actual capsule through each closed bulkhead. A thin
	# centre ray alone would miss the tiny decorative seam between door leaves.
	for door: Dictionary in vessel.doors:
		var normal: Vector3 = door.root.global_basis.z
		var start: Vector3 = door.root.global_position + normal * 1.5 + Vector3.UP * 0.08
		_check(explorer.test_move(Transform3D(Basis.IDENTITY, start), -normal * 3.0), "Closed bulkhead fails to block capsule: " + door.title)
		_vessel_floor(door.root.global_position)
		door.open = true
	await _frames(100)
	for door: Dictionary in vessel.doors:
		var normal: Vector3 = door.root.global_basis.z
		var start: Vector3 = door.root.global_position + normal * 1.5 + Vector3.UP * 0.08
		_check(door.amount > 0.99, "Bulkhead did not finish opening: " + door.title)
		_check(not explorer.test_move(Transform3D(Basis.IDENTITY, start), -normal * 3.0), "Open bulkhead obstructs capsule: " + door.title)
	# Walk through every connection using the production movement controller.
	var routes := [
		["bridge via central spine", Vector3(0, 0.15, 23), Vector3(0, 0.15, -30)],
		["aft airlock", Vector3(0, 0.15, 28), Vector3(0, 0.15, 36)],
		["engine room", Vector3(0, 0.15, 0), Vector3(-7.0, 0.15, 0)],
		["cargo hold", Vector3(0, 0.15, 7), Vector3(10, 0.15, 7)],
		["machine shop", Vector3(0, 0.15, 25), Vector3(-10, 0.15, 25)],
		["observation", Vector3(0, 0.15, -19), Vector3(10, 0.15, -19)],
		["cargo gallery stairs", Vector3(5.4, 0.15, 12.9), Vector3(5.4, 1.55, 18.5)]
	]
	for route: Array in routes:
		await _walk(route[0], route[1], route[2])
	_check(explorer.global_position.y > 1.4, "Gallery cannot be reached at its raised height")
	# Check boundary walls and both large exterior windows at standing height.
	var boundaries := [
		["bridge windows", Vector3(0, 1.8, -45), Vector3(0, 1.8, -47)],
		["observation windows", Vector3(14, 1.8, -19), Vector3(16, 1.8, -19)],
		["engine hull", Vector3(-18, 1.8, 0), Vector3(-20, 1.8, 0)],
		["cargo hull", Vector3(20, 1.8, 7), Vector3(22, 1.8, 7)],
		["aft external hatch", Vector3(0, 1.8, 38.5), Vector3(0, 1.8, 41)]
	]
	for boundary: Array in boundaries:
		var query := PhysicsRayQueryParameters3D.create(boundary[1], boundary[2])
		query.exclude = [explorer.get_rid()]
		_check(not vessel.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Exterior boundary has no collision: " + boundary[0])
	# A closing door must reopen while the player occupies its opening.
	explorer.set_control_enabled(false)
	var safety_door: Dictionary = vessel.doors[0]
	explorer.global_position = safety_door.root.global_position + Vector3.UP * 0.05
	explorer.velocity = Vector3.ZERO
	safety_door.open = false
	await _frames(3)
	_check(safety_door.open, "Occupied bulkhead failed to reopen")
	print("TRAVERSAL: %d checks; %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("TRAVERSAL PASS: seven destinations, four opening bulkheads, raised gallery, hull collision, safety interlock.")
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _vessel_floor(point: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point + Vector3.DOWN * 0.6)
	query.exclude = [explorer.get_rid()]
	_check(not vessel.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Missing collision floor at doorway " + str(point))

func _walk(title: String, start: Vector3, target: Vector3) -> void:
	Input.action_release("move_forward")
	explorer.set_control_enabled(false)
	explorer.global_position = start
	explorer.velocity = Vector3.ZERO
	var direction := (target - start)
	direction.y = 0.0
	var distance := direction.length()
	direction = direction.normalized()
	explorer.rotation.y = atan2(-direction.x, -direction.z)
	await _frames(5)
	explorer.set_control_enabled(true)
	Input.action_press("move_forward")
	var reached := false
	var limit: int = int(distance / explorer.walk_speed * 60.0 * 1.6) + 90
	for frame in range(limit):
		await physics_frame
		var planar := Vector2(explorer.global_position.x - target.x, explorer.global_position.z - target.z)
		if planar.length() < 0.22:
			reached = true
			break
		if explorer.global_position.y < -0.5:
			break
	Input.action_release("move_forward")
	explorer.set_control_enabled(false)
	_check(reached, "Player cannot reach " + title + "; stopped at " + str(explorer.global_position))
	_check(explorer.global_position.y > -0.1, "Player fell through deck on route " + title)
	print("ROUTE: ", title, " -> ", explorer.global_position, " / ", "PASS" if reached else "FAIL")
