class_name FirstPersonAgent
extends CharacterBody3D

signal interaction_requested(target: Node)
signal focus_changed(target: Node)
signal scanner_requested
signal fell_outside_world

const WALK_SPEED := 2.8
const SPRINT_SPEED := 6.3
const CROUCH_SPEED := 1.25
const STANDING_HEIGHT := 1.76
const CROUCH_HEIGHT := 1.12
const STEP_HEIGHT := 0.28

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var collider: CollisionShape3D = $Collision
@onready var flashlight: SpotLight3D = $Head/Camera/Flashlight

var controls_enabled: bool = false
var stamina: float = 100.0
var crouching: bool = false
var sprinting: bool = false
var focus_target: Node = null
var _pitch: float = 0.0
var _exhausted: bool = false
var _bob_phase: float = 0.0
var _step_distance: float = 0.0
var _step_visual_offset: float = 0.0
var _height: float = STANDING_HEIGHT
var _focus_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.fov = Preferences.field_of_view


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * Preferences.sensitivity)
		var direction := -1.0 if Preferences.invert_mouse else 1.0
		_pitch = clampf(_pitch - motion.relative.y * Preferences.sensitivity * direction, -1.44, 1.44)
		head.rotation.x = _pitch
	elif event.is_action_pressed("interact") and is_instance_valid(focus_target):
		interaction_requested.emit(focus_target)
	elif event.is_action_pressed("scanner"):
		scanner_requested.emit()
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Soundscape.play_ui("click")


func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if controls_enabled:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_update_crouch(delta)
	sprinting = controls_enabled and Input.is_action_pressed("sprint") and not crouching and not _exhausted and input_vector.y < -0.1
	if sprinting and input_vector.length() > 0.1 and is_on_floor():
		stamina = maxf(0.0, stamina - 16.0 * delta)
		if stamina <= 0.0:
			_exhausted = true
	else:
		stamina = minf(100.0, stamina + 19.0 * delta)
		if stamina >= 25.0:
			_exhausted = false
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var acceleration := 16.0 if is_on_floor() else 5.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif controls_enabled and Input.is_action_just_pressed("jump") and not crouching:
		velocity.y = 4.35
		Soundscape.play_world("cloth", global_position, -16.0)
	else:
		velocity.y = minf(velocity.y, 0.0)
	_try_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	var old_position := global_position
	move_and_slide()
	var traveled := Vector2(global_position.x - old_position.x, global_position.z - old_position.z).length()
	_update_camera(delta, traveled, input_vector)
	_focus_timer += delta
	if _focus_timer >= 0.06:
		_focus_timer = 0.0
		_update_focus()
	if global_position.y < -4.0:
		fell_outside_world.emit()


func _update_crouch(delta: float) -> void:
	var wants_crouch := controls_enabled and Input.is_action_pressed("crouch")
	if not wants_crouch and crouching and not _can_stand():
		wants_crouch = true
	crouching = wants_crouch
	_height = move_toward(_height, CROUCH_HEIGHT if crouching else STANDING_HEIGHT, delta * 3.0)
	var shape := collider.shape as CapsuleShape3D
	shape.height = _height
	collider.position.y = _height * 0.5
	head.position.y = lerpf(head.position.y, 1.02 if crouching else 1.64, 1.0 - exp(-delta * 12.0))


func _can_stand() -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.275
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 1.48, 0.0))
	query.collision_mask = 3
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _try_step_up(motion: Vector3) -> void:
	if not is_on_floor() or velocity.y > 0.1 or motion.length_squared() < 0.00001:
		return
	if not test_move(global_transform, motion):
		return
	var raised := global_transform
	raised.origin.y += STEP_HEIGHT
	if test_move(raised, motion):
		return
	raised.origin += motion
	var collision := KinematicCollision3D.new()
	if not test_move(raised, Vector3.DOWN * (STEP_HEIGHT + 0.04), collision):
		return
	if collision.get_normal().y < 0.85:
		return
	var height_delta := STEP_HEIGHT + collision.get_travel().y
	if height_delta <= 0.01 or height_delta > STEP_HEIGHT:
		return
	global_position.y += height_delta
	_step_visual_offset -= height_delta


func _update_camera(delta: float, distance: float, input_vector: Vector2) -> void:
	var step_length := 1.85 if sprinting else (1.0 if crouching else 1.2)
	if is_on_floor() and distance > 0.001:
		_bob_phase += distance / step_length * PI
		_step_distance += distance
		if _step_distance >= step_length:
			_step_distance = fmod(_step_distance, step_length)
			Soundscape.footstep(global_position, CaseState.zone == "egypt", crouching)
	_step_visual_offset = move_toward(_step_visual_offset, 0.0, delta * 1.8)
	var bob := absf(sin(_bob_phase)) * 0.038 * Preferences.camera_motion if distance > 0.001 and is_on_floor() else 0.0
	camera.position.y = lerpf(camera.position.y, bob + _step_visual_offset, 1.0 - exp(-delta * 13.0))
	camera.rotation.z = lerpf(camera.rotation.z, -input_vector.x * 0.016 * Preferences.camera_motion, 1.0 - exp(-delta * 7.0))
	camera.fov = lerpf(camera.fov, Preferences.field_of_view + (4.0 if sprinting else 0.0), 1.0 - exp(-delta * 7.0))


func _update_focus() -> void:
	var target: Node = null
	if controls_enabled:
		var query := PhysicsRayQueryParameters3D.create(
			camera.global_position, camera.global_position - camera.global_basis.z * 3.6, 7, [get_rid()]
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var candidate: Node = hit["collider"]
			if candidate is TemporalInteractable or candidate is TemporalNPC:
				target = candidate
	if target != focus_target:
		focus_target = target
		focus_changed.emit(target)


func teleport_to(point: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	global_position = point
	rotation.y = yaw
	_pitch = clampf(pitch, -1.44, 1.44)
	head.rotation.x = _pitch
	velocity = Vector3.ZERO
	_step_visual_offset = 0.0
	_step_distance = 0.0
	reset_physics_interpolation()


func snapshot() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y, "pitch": _pitch, "stamina": stamina
	}
