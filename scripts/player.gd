extends CharacterBody3D
## A weighty, unobstructed first-person observer. The player has no visible body.

signal interact_requested(origin: Vector3, direction: Vector3)
signal footstep(speed: float)
signal flashlight_changed(enabled: bool)

const STANDING_HEIGHT: float = 1.78
const CROUCHING_HEIGHT: float = 1.12
const EYE_HEIGHT: float = 1.62

var camera: Camera3D
var flashlight: SpotLight3D
var active: bool = false
var head_bob_enabled: bool = true
var mouse_sensitivity: float = 0.0018
var walk_speed: float = 2.25
var sprint_speed: float = 3.6
var crouch_speed: float = 1.2
var is_crouching: bool = false
var movement_amount: float = 0.0
var _pitch: float = 0.0
var _bob_clock: float = 0.0
var _step_phase: float = 0.0
var _flashlight_on: bool = true
var _capsule: CapsuleShape3D
var _collision: CollisionShape3D
var _base_eye: float = EYE_HEIGHT
var _sway: Vector2 = Vector2.ZERO
var _last_safe_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	name = "Observer"
	_install_actions()
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(48.0)
	max_slides = 6
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.28
	_capsule.height = STANDING_HEIGHT
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = STANDING_HEIGHT * 0.5
	add_child(_collision)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.current = true
	camera.position.y = EYE_HEIGHT
	camera.fov = 72.0
	camera.near = 0.04
	camera.far = 180.0
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "InspectionLamp"
	flashlight.position = Vector3(0.19, -0.16, -0.15)
	flashlight.light_color = Color(1.0, 0.83, 0.59)
	flashlight.light_energy = 1.4
	flashlight.spot_range = 14.0
	flashlight.spot_angle = 31.0
	flashlight.spot_angle_attenuation = 1.7
	flashlight.spot_attenuation = 0.8
	flashlight.shadow_enabled = true
	flashlight.shadow_bias = 0.035
	flashlight.light_volumetric_fog_energy = 0.22
	camera.add_child(flashlight)
	_last_safe_position = global_position
	add_to_group("player")


func start() -> void:
	set_control_enabled(true)


func set_control_enabled(enabled: bool) -> void:
	active = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
		_sway += event.relative * 0.00012
		_sway = _sway.clamp(Vector2(-0.025, -0.025), Vector2(0.025, 0.025))
	if event.is_action_pressed("flashlight"):
		_flashlight_on = not _flashlight_on
		flashlight.visible = _flashlight_on
		flashlight_changed.emit(_flashlight_on)
	if event.is_action_pressed("interact"):
		interact_requested.emit(camera.global_position, -camera.global_basis.z)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.1
		_last_safe_position = global_position
	var axis: Vector2 = Vector2.ZERO
	var wants_crouch: bool = false
	if active:
		axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wants_crouch = Input.is_action_pressed("crouch")
	if wants_crouch != is_crouching:
		if wants_crouch or _can_stand():
			is_crouching = wants_crouch
			_capsule.height = CROUCHING_HEIGHT if is_crouching else STANDING_HEIGHT
			_collision.position.y = _capsule.height * 0.5
	var speed: float = walk_speed
	if is_crouching:
		speed = crouch_speed
	elif active and Input.is_action_pressed("sprint") and axis.y < 0.0:
		speed = sprint_speed
	var direction: Vector3 = global_basis * Vector3(axis.x, 0.0, axis.y)
	var acceleration: float = 10.0 if direction.length_squared() > 0.0 else 14.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()
	if global_position.y < -8.0:
		global_position = _last_safe_position + Vector3.UP * 0.15
		velocity = Vector3.ZERO
	movement_amount = Vector2(velocity.x, velocity.z).length()
	_update_camera(delta)
	if active and is_on_floor() and movement_amount > 0.5:
		_step_phase += movement_amount * delta
		if _step_phase > (1.8 if not is_crouching else 1.45):
			_step_phase = 0.0
			footstep.emit(movement_amount)
	else:
		_step_phase = 1.1


func _update_camera(delta: float) -> void:
	var eye_target: float = 1.0 if is_crouching else EYE_HEIGHT
	_base_eye = lerpf(_base_eye, eye_target, 1.0 - exp(-12.0 * delta))
	var bob: Vector3 = Vector3.ZERO
	if head_bob_enabled and is_on_floor() and active:
		_bob_clock += movement_amount * delta * 3.2
		var strength: float = minf(movement_amount / walk_speed, 1.4)
		bob.x = sin(_bob_clock * 0.5) * 0.0126 * strength
		bob.y = sin(_bob_clock) * 0.0161 * strength
	camera.position = Vector3(bob.x, _base_eye + bob.y, 0.0)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-7.0 * delta))
	var lean: float = -global_basis.x.dot(velocity) * 0.0025 if head_bob_enabled else 0.0
	camera.rotation = Vector3(_pitch, 0.0, lerpf(camera.rotation.z, lean, 1.0 - exp(-7.0 * delta)))
	flashlight.rotation = Vector3(-_sway.y, -_sway.x, 0.0)
	var fov_target: float = 75.0 if movement_amount > walk_speed + 0.2 else 72.0
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-3.0 * delta))


func _can_stand() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.02, global_position + Vector3.UP * 1.85)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _install_actions() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT])
	_bind("crouch", [KEY_CTRL])
	_bind("flashlight", [KEY_F])
	_bind("interact", [KEY_E])
	_bind("pause", [KEY_ESCAPE])
	_bind("deck_map", [KEY_M, KEY_TAB])


func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
