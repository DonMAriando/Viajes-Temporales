class_name TemporalNPC
extends CharacterBody3D

var npc_id: String = ""
var display_name: String = ""
var suspect: bool = false
var conversing: bool = false
var capture_pressure: bool = false
var patrol_points: Array[Vector3] = []
var escape_route: Array[Vector3] = []
var spawn_point: Vector3 = Vector3.ZERO
var model: Node3D
var animation_player: AnimationPlayer
var navigation: NavigationAgent3D
var _animations: Dictionary = {}
var _stride_lengths: Dictionary = {}
var _patrol_index: int = 0
var _patrol_target_set: bool = false
var _route_index: int = 0
var _wait: float = 1.5
var _fleeing: bool = false
var _returning: bool = false
var _last_animation: String = ""
var _footstep_distance: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 11
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	var stature_factor := 0.98 if suspect else 0.90 + posmod(npc_id.hash(), 5) * 0.007
	capsule.height = 1.82 * stature_factor
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	model = AssetLibrary.character(suspect)
	model.scale = Vector3.ONE * stature_factor
	add_child(model)
	for node: Node in model.find_children("Body", "MeshInstance3D", true, false):
		var geometry := node as MeshInstance3D
		var source := geometry.get_active_material(0) as StandardMaterial3D
		if source != null:
			var skin := source.duplicate() as StandardMaterial3D
			skin.subsurf_scatter_enabled = true
			skin.subsurf_scatter_strength = 0.08
			skin.subsurf_scatter_skin_mode = true
			geometry.set_surface_override_material(0, skin)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(animation_player != null, "El personaje necesita sus animaciones esqueléticas.")
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	for name: String in animation_player.get_animation_list():
		for action: String in ["idle", "walk", "run", "captured"]:
			if name == action or name.ends_with("/" + action):
				_animations[action] = name
				animation_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null, "El personaje necesita un esqueleto articulado.")
	var stride_data: Variant = skeleton.get_parent().get_meta("extras")
	assert(stride_data is Dictionary, "El modelo necesita las medidas de sus zancadas.")
	for action: String in ["walk", "run"]:
		var stride: Variant = stride_data.get(action + "_stride")
		assert((stride is float or stride is int) and float(stride) > 0.0, "Falta la zancada de %s." % action)
		_stride_lengths[action] = float(stride)
	navigation = NavigationAgent3D.new()
	navigation.path_desired_distance = 0.65
	navigation.target_desired_distance = 0.8
	navigation.radius = 0.3
	navigation.height = 1.75
	navigation.max_speed = 4.9
	add_child(navigation)
	spawn_point = position
	add_to_group("npcs")
	_play("idle")


func _physics_process(delta: float) -> void:
	var map := navigation.get_navigation_map()
	var navigation_ready := map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0
	var desired := Vector3.ZERO
	var speed := 1.3
	if not (suspect and CaseState.captured) and not conversing and navigation_ready:
		if suspect and CaseState.chase_active:
			if not _fleeing or _returning:
				_fleeing = true
				_returning = false
				_route_index = _nearest_route_index()
				_set_route_target()
			speed = 1.5 if capture_pressure else 4.9
			var direction := _path_direction()
			if navigation.is_navigation_finished() and not escape_route.is_empty():
				_route_index = mini(_route_index + 1, escape_route.size() - 1)
				_set_route_target()
				direction = _path_direction()
			desired = direction * speed
		elif suspect and _fleeing:
			if not _returning:
				_returning = true
				navigation.target_position = spawn_point
			desired = _path_direction() * 2.0
			if global_position.distance_to(spawn_point) < 1.0:
				_fleeing = false
				_returning = false
		elif not suspect and not patrol_points.is_empty():
			_wait = maxf(0.0, _wait - delta)
			if _wait <= 0.0:
				if not _patrol_target_set:
					_patrol_index = (_patrol_index + 1) % patrol_points.size()
					navigation.target_position = patrol_points[_patrol_index]
					_patrol_target_set = true
				var direction := _path_direction()
				if navigation.is_navigation_finished():
					_patrol_index = (_patrol_index + 1) % patrol_points.size()
					navigation.target_position = patrol_points[_patrol_index]
					_wait = 1.5
				else:
					desired = direction * speed
	velocity.x = move_toward(velocity.x, desired.x, delta * 9.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 9.0)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	var motion := global_position - before
	var moved := Vector2(motion.x, motion.z).length()
	var horizontal_speed := moved / maxf(delta, 0.001)
	if horizontal_speed > 0.08:
		rotation.y = lerp_angle(rotation.y, atan2(motion.x, motion.z), 1.0 - exp(-delta * 7.0))
	if suspect and CaseState.captured:
		_play("captured")
		animation_player.speed_scale = 1.0
		_footstep_distance = 0.0
	else:
		var action := "run" if horizontal_speed > 2.5 else ("walk" if horizontal_speed > 0.08 else "idle")
		_play(action)
		if action == "idle":
			animation_player.speed_scale = 1.0
			_footstep_distance = 0.0
		else:
			var stride := float(_stride_lengths[action]) * model.scale.y
			var duration := animation_player.get_animation(String(_animations[action])).length
			animation_player.speed_scale = horizontal_speed * duration / stride
			_footstep_distance += moved
			if _footstep_distance >= stride * 0.5:
				_footstep_distance = fmod(_footstep_distance, stride * 0.5)
				Soundscape.footstep(global_position, true, false, -10.0)


func _path_direction() -> Vector3:
	var map := navigation.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return Vector3.ZERO
	var next_position := navigation.get_next_path_position()
	if navigation.is_navigation_finished():
		return Vector3.ZERO
	var direction := next_position - global_position
	direction.y = 0.0
	return direction.normalized()


func _set_route_target() -> void:
	if not escape_route.is_empty():
		navigation.target_position = escape_route[_route_index]


func _nearest_route_index() -> int:
	var result := 0
	var distance := INF
	for index: int in range(escape_route.size()):
		var candidate := global_position.distance_to(escape_route[index])
		if candidate < distance:
			result = index
			distance = candidate
	return result


func _play(action: String) -> void:
	if action == _last_animation:
		return
	assert(_animations.has(action), "Falta la animación %s." % action)
	var preserve_phase := action in ["walk", "run"] and _last_animation in ["walk", "run"]
	var phase := 0.0
	if preserve_phase:
		phase = animation_player.current_animation_position / animation_player.current_animation_length
	animation_player.play(String(_animations[action]), 0.22)
	if preserve_phase:
		animation_player.seek(phase * animation_player.current_animation_length, true)
	_last_animation = action


func face_point(point: Vector3, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-delta * 5.0))


func prompt() -> String:
	if suspect:
		if CaseState.captured:
			return "Marcus Vale · bajo custodia"
		if CaseState.chase_active:
			return "Mantén E · captura no letal"
		return "Identificar · Marcus Vale" if not CaseState.warrant_suspect.is_empty() else "Hablar · trabajador desconocido"
	return "Hablar · %s" % display_name


func navigation_snapshot() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y, "route_index": _route_index, "fleeing": _fleeing,
		"returning": _returning
	}


func restore_navigation(snapshot: Dictionary) -> bool:
	var coordinates: Variant = snapshot.get("position")
	if not coordinates is Array or coordinates.size() != 3:
		return false
	for value: Variant in coordinates:
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	var point := Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	if absf(point.x) > 90.0 or point.z < -40.0 or point.z > 80.0 or point.y < -2.0 or point.y > 15.0:
		return false
	global_position = point
	rotation.y = float(snapshot.get("yaw", 0.0))
	_route_index = clampi(int(snapshot.get("route_index", 0)), 0, maxi(0, escape_route.size() - 1))
	_fleeing = bool(snapshot.get("fleeing", false))
	_returning = bool(snapshot.get("returning", false))
	if _returning:
		navigation.target_position = spawn_point
	elif _fleeing:
		_set_route_target()
	reset_physics_interpolation()
	return true
