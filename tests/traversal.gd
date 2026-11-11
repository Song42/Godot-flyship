extends SceneTree
## End-to-end walks through furnished cabins and open decks using real collision.
## godot --headless --path . --fixed-fps 60 --script tests/traversal.gd

var vessel: Node3D
var explorer: CharacterBody3D
var failures: Array[String] = []
var checks: int = 0
var routes_completed: int = 0

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
	_check(vessel.room_bounds.size() == 14, "All fourteen interior and exterior areas must exist")
	_check(vessel.doors.size() == 13, "All thirteen cabin and exterior doors must exist")
	_check(vessel.environment.background_mode == Environment.BG_COLOR and vessel.environment.background_color == Color.BLACK, "Night sky must remain entirely black")
	for room: Dictionary in vessel.room_bounds:
		var center: Vector2 = room.rect.get_center()
		_check(_has_floor(Vector3(center.x, 0.0, center.y)), "Missing deck under " + room.name)
	# A short capsule sweep crosses the whole doorway without touching furniture.
	for door: Dictionary in vessel.doors:
		var normal: Vector3 = door.root.global_basis.z
		var start: Vector3 = door.root.global_position + normal * 0.65 + Vector3.UP * 0.08
		_check(explorer.test_move(Transform3D(Basis.IDENTITY, start), -normal * 1.3), "Closed door does not block capsule: " + door.title)
		var threshold: Vector3 = door.root.global_position
		# Shared deck edges can reject a ray exactly on their floating-point seam.
		var supported: bool = _has_floor(threshold) or (_has_floor(threshold + normal * 0.08) and _has_floor(threshold - normal * 0.08))
		_check(supported, "No floor beneath door: " + door.title)
		door.open = true
	await _frames(105)
	for door: Dictionary in vessel.doors:
		var normal: Vector3 = door.root.global_basis.z
		var start: Vector3 = door.root.global_position + normal * 0.65 + Vector3.UP * 0.08
		_check(door.amount > 0.99, "Door does not finish opening: " + door.title)
		_check(not explorer.test_move(Transform3D(Basis.IDENTITY, start), -normal * 1.3), "Open door obstructs capsule: " + door.title)
	# Teleport only between independent routes; traverse each waypoint physically.
	var routes: Array = [
		["main passage", [Vector2(0, 15.8), Vector2(0, -11.1)]],
		["crew cabin A", [Vector2(0, -10), Vector2(-2.5, -10)]],
		["crew cabin B", [Vector2(0, -6), Vector2(-2.5, -6)]],
		["captain's cabin", [Vector2(0, 0), Vector2(-2.4, 0)]],
		["mess room", [Vector2(0, -8), Vector2(1.5, -8), Vector2(1.6, -9.85)]],
		["galley", [Vector2(0, 2), Vector2(2.2, 2)]],
		["engine room", [Vector2(0, 7), Vector2(-1.85, 7), Vector2(-1.85, 10.5)]],
		["workshop", [Vector2(0, 14.5), Vector2(-2.3, 14.5)]],
		["cargo hold", [Vector2(0, 12), Vector2(2.0, 12)]],
		["mess to balcony", [Vector2(0, -8), Vector2(1.5, -8), Vector2(1.6, -9.85), Vector2(4.95, -9.85), Vector2(4.95, -8), Vector2(7.0, -8)]],
		["cargo to balcony", [Vector2(0, 12), Vector2(2.0, 12), Vector2(5.0, 12), Vector2(7.0, 12)]],
		["entire balcony", [Vector2(7.0, 16), Vector2(7.0, -13.2)]],
		["chart room", [Vector2(0, -11), Vector2(0, -13.0)]],
		["chart to port walkway", [Vector2(0, -13), Vector2(-2.5, -13), Vector2(-2.5, -15), Vector2(-4.5, -15)]],
		["chart to starboard walkway", [Vector2(0, -13), Vector2(1.8, -13), Vector2(1.8, -15), Vector2(4.5, -15)]],
		["port walkway to foredeck", [Vector2(-4.2, -13), Vector2(-4.2, -25), Vector2(-2.0, -25)]],
		["starboard walkway to foredeck", [Vector2(4.5, -13), Vector2(4.5, -25), Vector2(2.0, -25)]],
		["wheelhouse and foredeck", [Vector2(0, -17), Vector2(0, -21), Vector2(0, -24.5)]]
	]
	for route: Array in routes:
		await _walk_path(str(route[0]), route[1])
	# Railings are below eye height; test the player's capsule, not an eye ray.
	var boundaries: Array = [
		["foredeck bow rail", Vector3(3.0, 0.08, -27), Vector3(0, 0, -2)],
		["port walkway rail", Vector3(-4.8, 0.08, -16), Vector3(-2, 0, 0)],
		["starboard walkway rail", Vector3(4.8, 0.08, -18.5), Vector3(2, 0, 0)],
		["balcony outer rail", Vector3(7.0, 0.08, 0), Vector3(2, 0, 0)],
		["balcony aft rail", Vector3(7.0, 0.08, 16), Vector3(0, 0, 2)],
		["balcony forward rail", Vector3(7.0, 0.08, -13), Vector3(0, 0, -2)],
		["stern passage wall", Vector3(0, 0.08, 16), Vector3(0, 0, 2)]
	]
	for boundary: Array in boundaries:
		_check(explorer.test_move(Transform3D(Basis.IDENTITY, boundary[1]), boundary[2]), "Exterior edge does not stop player: " + boundary[0])
	explorer.set_control_enabled(false)
	var safety_door: Dictionary = vessel.doors[0]
	explorer.global_position = safety_door.root.global_position + Vector3.UP * 0.05
	explorer.velocity = Vector3.ZERO
	safety_door.open = false
	await _frames(3)
	_check(safety_door.open, "Occupied door failed to reopen")
	print("TRAVERSAL: %d routes; %d checks; %d failures" % [routes_completed, checks, failures.size()])
	if failures.is_empty():
		print("TRAVERSAL PASS: cabins, mess, machinery, wheelhouse, decks, balcony, door safety and railings.")
	vessel.queue_free()
	await process_frame
	# Fixed-fps mode advances timers faster than the threaded audio mixer.
	OS.delay_msec(80)
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _has_floor(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.12, point + Vector3.DOWN * 0.6)
	query.exclude = [explorer.get_rid()]
	return not vessel.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _walk_path(title: String, waypoints: Array) -> void:
	Input.action_release("move_forward")
	explorer.set_control_enabled(false)
	explorer.global_position = Vector3(waypoints[0].x, 0.12, waypoints[0].y)
	explorer.velocity = Vector3.ZERO
	await _frames(6)
	var reached: bool = true
	for index in range(1, waypoints.size()):
		var target: Vector2 = waypoints[index]
		var current := Vector2(explorer.global_position.x, explorer.global_position.z)
		var direction: Vector2 = (target - current).normalized()
		var distance: float = current.distance_to(target)
		explorer.rotation.y = atan2(-direction.x, -direction.y)
		explorer.set_control_enabled(true)
		Input.action_press("move_forward")
		var segment_reached: bool = false
		var limit: int = int(distance / explorer.walk_speed * 60.0 * 1.5) + 75
		for frame in limit:
			await physics_frame
			var remaining := Vector2(explorer.global_position.x - target.x, explorer.global_position.z - target.y)
			if remaining.length() < 0.13:
				segment_reached = true
				break
			if explorer.global_position.y < -0.5:
				break
		Input.action_release("move_forward")
		explorer.set_control_enabled(false)
		if not segment_reached:
			_check(false, "%s waypoint %d %s blocked at %s" % [title, index, target, explorer.global_position])
			_report_contacts()
			reached = false
			break
	_check(reached, "Cannot complete walk: " + title)
	_check(explorer.global_position.y > -0.1, "Fell through deck during " + title)
	if reached:routes_completed += 1
	print("ROUTE: ", title, " -> ", explorer.global_position, " / ", "PASS" if reached else "FAIL")

func _report_contacts() -> void:
	for index in explorer.get_slide_collision_count():
		var collision: KinematicCollision3D = explorer.get_slide_collision(index)
		var collider: Object = collision.get_collider()
		if collider is Node:
			print("BLOCKER: ", collider.get_path(), " at ", collision.get_position())
