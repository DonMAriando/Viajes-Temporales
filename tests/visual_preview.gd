extends Node

var _main: Node3D
var _output: String = "user://previews"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	if directory_error != OK:
		push_error("No se pudo crear el directorio de capturas: %s." % error_string(directory_error))
		get_tree().quit(1)
		return
	Preferences.fullscreen = false
	Preferences.quality = 1
	CaseState.save_path = "user://verification/preview_unused.json"
	var scene: PackedScene = load("res://scenes/main.tscn")
	_main = scene.instantiate()
	_main._suppress_autosave = true
	get_tree().root.add_child(_main)
	await _draw_frames(30)
	await _capture("01_menu.png")
	CaseState.begin_case()
	_main._in_game = true
	_main.ui.overlay_kind = "preview"
	_main.ui.close_overlay()
	_main.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_main.player.teleport_to(Vector3(0, 0.05, 7.5))
	_aim_at(Vector3(0, 1.7, 12))
	await _draw_frames(30)
	await _capture("06_acceso_agencia.png")
	CaseState.zone = "egypt"
	CaseState.phase = "investigation"
	_main._in_game = true
	_main._build_world("egypt")
	_main.ui.overlay_kind = "preview"
	_main.ui.close_overlay()
	_main.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_main.player.teleport_to(_main.world.spawn_point, 0.0, -0.03)
	await _draw_frames(90)
	await _capture("02_guiza.png")
	_main.player.teleport_to(Vector3(-19.2, 0.05, 32.1))
	var merchant: TemporalNPC
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if (node as TemporalNPC).npc_id == "merchant":
			merchant = node
	if not is_instance_valid(merchant):
		push_error("Falta Menna en la escena histórica.")
		get_tree().quit(1)
		return
	merchant.rotation.y = atan2(_main.player.global_position.x - merchant.global_position.x, _main.player.global_position.z - merchant.global_position.z)
	_aim_at(merchant.global_position + Vector3(0, 1.0, 0))
	await _draw_frames(20)
	await _capture("03_personaje.png")
	await _character_views(merchant)
	_main.ui.show_dialogue("merchant")
	await _draw_frames(10)
	await _capture("04_dialogo.png")
	_main.ui.close_overlay()
	for id: String in ["alloy", "travel_log", "intercept", "merchant", "payment", "scribe"]:
		CaseState.collect_evidence(id)
		if not CaseState.analyzed.has(id):
			CaseState.analyze_evidence(id)
	_main.ui.show_journal("Evidencias")
	await _draw_frames(10)
	await _capture("05_expediente.png")
	Soundscape.stop_all()
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await _draw_frames(8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()


func _character_views(npc: TemporalNPC) -> void:
	var original_position: Vector3 = _main.player.global_position
	var original_fov: float = _main.player.camera.fov
	for view: Dictionary in [
		{"name": "07_cintura_frente.png", "offset": Vector3(0, 0, 1.15)},
		{"name": "07_cintura_lateral.png", "offset": Vector3(1.15, 0, 0)},
		{"name": "07_cintura_espalda.png", "offset": Vector3(0, 0, -1.15)}
	]:
		_main.player.teleport_to(npc.global_position + view["offset"])
		_aim_at(npc.global_position + Vector3(0, 1.0, 0))
		await _draw_frames(10)
		await _capture(view["name"])
	npc.set_physics_process(false)
	_main.player.camera.fov = 50.0
	_main.player.teleport_to(npc.global_position + Vector3(1.4, 0, 2.1))
	_aim_at(npc.global_position + Vector3(0, 0.95, 0))
	for action: String in ["walk", "run"]:
		npc.animation_player.play(String(npc._animations[action]), 0.0)
		npc.animation_player.pause()
		var duration := npc.animation_player.get_animation(String(npc._animations[action])).length
		for frame: int in range(4):
			npc.animation_player.seek(duration * frame / 4.0, true)
			await _draw_frames(5)
			await _capture("08_%s_%s.png" % [action, frame])
	npc.animation_player.play(String(npc._animations["idle"]), 0.0)
	npc.set_physics_process(true)
	_main.player.camera.fov = original_fov
	_main.player.teleport_to(original_position)
	_aim_at(npc.global_position + Vector3(0, 1.0, 0))
	await _draw_frames(10)


func _aim_at(point: Vector3) -> void:
	var direction: Vector3 = point - _main.player.camera.global_position
	_main.player.teleport_to(
		_main.player.global_position, atan2(-direction.x, -direction.z),
		atan2(direction.y, Vector2(direction.x, direction.z).length())
	)


func _draw_frames(count: int) -> void:
	for i: int in range(count):
		await RenderingServer.frame_post_draw


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var destination := _output.path_join(filename)
	var error := image.save_png(destination)
	if error != OK:
		push_error("No se pudo guardar %s: %s." % [filename, error_string(error)])
		get_tree().quit(1)
		return
	print("CAPTURE: %s (%s x %s; %s FPS)" % [filename, image.get_width(), image.get_height(), Engine.get_frames_per_second()])
