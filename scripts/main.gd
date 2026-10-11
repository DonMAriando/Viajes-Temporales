extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var world: TemporalWorld
var player: FirstPersonAgent
var ui: GameUI
var _in_game: bool = false
var _transitioning: bool = false
var _suppress_autosave: bool = false
var _capture_progress: float = 0.0
var _scanner_seconds: float = 0.0
var _scanner_cooldown: float = 0.0
var _autosave_seconds: float = 0.0
var _conversation_npc: TemporalNPC
var _quitting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	ui = GameUI.new()
	add_child(ui)
	ui.new_case_requested.connect(_start_new_case)
	ui.continue_requested.connect(_continue_case)
	ui.menu_requested.connect(_return_to_menu)
	ui.save_requested.connect(func() -> void: persist_game(true))
	ui.quit_requested.connect(_quit_game)
	ui.overlay_changed.connect(_overlay_changed)
	CaseState.zone_changed.connect(_transition_to)
	CaseState.changed.connect(_case_changed)
	CaseState.notification.connect(_notify)
	Preferences.updated.connect(_preferences_changed)
	Preferences.storage_error.connect(func(message: String) -> void: ui.toast(message, true))
	_build_world("hub")
	player.teleport_to(Vector3(5.8, 0.1, 7), 0.3, -0.015)
	Preferences.apply()
	ui.show_menu()


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(world):
		return
	ui.update_hud(player, world, _capture_progress, _scanner_cooldown)
	if is_instance_valid(_conversation_npc) and ui.overlay_kind == "dialogue":
		_conversation_npc.face_point(player.global_position, delta)
	if get_tree().paused or not _in_game or _transitioning:
		return
	_scanner_seconds = maxf(0.0, _scanner_seconds - delta)
	_scanner_cooldown = maxf(0.0, _scanner_cooldown - delta)
	_update_scanner()
	_update_capture(delta)
	_autosave_seconds += delta
	if _autosave_seconds >= 45.0:
		_autosave_seconds = 0.0
		persist_game(false)
	if CaseState.zone == "egypt" and (player.global_position.x < -86.0 or player.global_position.z > 88.0):
		_recover_player()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("pause"):
		if not ui.overlay_kind.is_empty():
			ui.close_overlay()
		elif _in_game:
			ui.show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal") and _in_game:
		if ui.overlay_kind == "journal":
			ui.close_overlay()
		elif ui.overlay_kind.is_empty() or ui.overlay_kind == "pause":
			ui.show_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quicksave") and _in_game:
		persist_game(true)
		get_viewport().set_input_as_handled()


func _build_world(destination: String, snapshot: Dictionary = {}) -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	_conversation_npc = null
	world = TemporalWorld.new()
	add_child(world)
	world.build(destination)
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.teleport_to(world.spawn_point, world.spawn_yaw)
	player.interaction_requested.connect(_interact)
	player.scanner_requested.connect(_activate_scanner)
	player.fell_outside_world.connect(_recover_player)
	ui.world = world
	ui.player = player
	_capture_progress = 0.0
	_scanner_seconds = 0.0
	_scanner_cooldown = 0.0
	if not snapshot.is_empty():
		if not _restore_agent(snapshot):
			ui.toast("El punto de control no era seguro. Se recuperó la posición de llegada.", true)
		if destination == "egypt" and snapshot.has("suspect"):
			if not world.suspect.restore_navigation(snapshot["suspect"]):
				ui.toast("La posición del sospechoso no era válida. Se conservó la investigación y se reinició su recorrido.", true)
	Soundscape.set_zone(destination)


func _restore_agent(snapshot: Dictionary) -> bool:
	var coordinates: Variant = snapshot.get("position")
	if not coordinates is Array or coordinates.size() != 3:
		return false
	for value: Variant in coordinates:
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	var point := Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	var yaw := float(snapshot.get("yaw", 0.0))
	var pitch := float(snapshot.get("pitch", 0.0))
	if not is_finite(yaw) or not is_finite(pitch) or point.y < -2.0 or point.y > 30.0:
		return false
	if world.zone == "hub" and (absf(point.x) > 12.0 or point.z < -17.5 or point.z > 11.5):
		return false
	if world.zone == "egypt" and (point.x < -85.0 or point.x > 84.0 or point.z < -65.0 or point.z > 86.0):
		return false
	player.teleport_to(point, yaw, pitch)
	player.stamina = clampf(float(snapshot.get("stamina", 100.0)), 0.0, 100.0)
	return true


func _start_new_case() -> void:
	if _transitioning:
		return
	_transitioning = true
	_suppress_autosave = true
	CaseState.begin_case()
	_in_game = true
	ui.show_loading("Centro de operaciones / Caso 001")
	await get_tree().process_frame
	_build_world("hub")
	_transitioning = false
	_suppress_autosave = false
	ui.finish_loading()
	ui.show_briefing()
	persist_game(false)


func _continue_case() -> void:
	if _transitioning:
		return
	_suppress_autosave = true
	var result: Dictionary = CaseState.load_game()
	_suppress_autosave = false
	if not bool(result["ok"]):
		return
	_in_game = true
	var snapshot := CaseState.checkpoint.duplicate(true)
	await _transition_to(CaseState.zone, snapshot)
	ui.toast(String(result["message"]))
	if CaseState.completed:
		ui.show_report()


func _transition_to(destination: String, snapshot: Dictionary = {}) -> void:
	if _transitioning:
		return
	_transitioning = true
	ui.show_loading("Guiza / c. 2560 a. C." if destination == "egypt" else "Centro de operaciones / Presente")
	Soundscape.play_ui("travel")
	await get_tree().create_timer(0.65).timeout
	_build_world(destination, snapshot)
	await get_tree().process_frame
	_transitioning = false
	ui.finish_loading()
	persist_game(false)


func _overlay_changed(opened: bool) -> void:
	get_tree().paused = opened or not _in_game or _transitioning
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(player):
		player.controls_enabled = not get_tree().paused
	if opened:
		_capture_progress = 0.0
	if is_instance_valid(world) and is_instance_valid(world.suspect):
		world.suspect.capture_pressure = false
	if is_instance_valid(_conversation_npc):
		var conversing := ui.overlay_kind == "dialogue"
		_conversation_npc.conversing = conversing
		_conversation_npc.animation_player.process_mode = Node.PROCESS_MODE_ALWAYS if conversing else Node.PROCESS_MODE_INHERIT
		if not conversing:
			_conversation_npc = null


func _interact(target: Node) -> void:
	if not _in_game or _transitioning or not ui.overlay_kind.is_empty() or not is_instance_valid(target):
		return
	if target is TemporalNPC:
		var npc := target as TemporalNPC
		if npc.suspect:
			if CaseState.captured:
				ui.toast("El detenido permanece bajo el campo de custodia del ancla. Completa la reparación y regresa.")
			else:
				_result(CaseState.begin_chase())
		elif CaseState.case_data["dialogues"].has(npc.npc_id):
			_conversation_npc = npc
			npc.conversing = true
			ui.show_dialogue(npc.npc_id)
		else:
			ui.toast("La cuadrilla está trabajando. Menna, Nefer, Hori y Seneb pueden aportar testimonios.")
		return
	if not target is TemporalInteractable:
		return
	var interactable := target as TemporalInteractable
	match interactable.kind:
		"evidence":
			_examine_evidence(interactable.interaction_id)
		"console":
			if CaseState.phase == "debrief":
				if bool(CaseState.complete_case()["ok"]):
					ui.show_report()
			elif CaseState.completed:
				ui.show_report()
			else:
				ui.show_journal()
		"portal":
			_result(CaseState.travel_to_egypt())
		"anchor":
			_result(CaseState.return_to_hub() if CaseState.repaired else CaseState.repair_timeline())
		"device":
			if not CaseState.analyzed.has("device"):
				_examine_evidence("device")
			elif CaseState.neutralized:
				ui.show_evidence("device")
			else:
				_result(CaseState.neutralize_device())


func _examine_evidence(id: String) -> void:
	if not CaseState.collected.has(id):
		var result: Dictionary = CaseState.collect_evidence(id)
		if not bool(result["ok"]):
			return
		Soundscape.play_ui("evidence")
	ui.show_evidence(id)


func _update_capture(delta: float) -> void:
	if not is_instance_valid(world.suspect):
		return
	world.suspect.capture_pressure = false
	var close_enough := player.global_position.distance_to(world.suspect.global_position) < 2.9
	var aiming := player.focus_target == world.suspect
	if CaseState.chase_active and close_enough and aiming and Input.is_action_pressed("interact"):
		world.suspect.capture_pressure = true
		_capture_progress = minf(1.0, _capture_progress + delta / 1.6)
		if _capture_progress >= 1.0:
			_result(CaseState.capture_suspect())
			_capture_progress = 0.0
	else:
		_capture_progress = maxf(0.0, _capture_progress - delta * 2.0)


func _activate_scanner() -> void:
	if _scanner_cooldown > 0.0:
		ui.toast("El escáner está recargando. No puede revelar una identidad ni atravesar paredes.")
		return
	_scanner_seconds = 3.0
	_scanner_cooldown = 8.0
	Soundscape.play_ui("scanner")
	_update_scanner()


func _update_scanner() -> void:
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		var target := node as TemporalInteractable
		if not is_instance_valid(target) or target.marker == null:
			continue
		var relevant := target.kind in ["evidence", "device"]
		var id := "device" if target.kind == "device" else target.interaction_id
		var visible := _scanner_seconds > 0.0 and relevant and not CaseState.collected.has(id)
		visible = visible and player.camera.global_position.distance_to(target.global_position) < 11.0
		if visible:
			var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, target.global_position, 7, [player.get_rid()])
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			visible = not hit.is_empty() and hit["collider"] == target
		target.marker.visible = visible


func _recover_player() -> void:
	if _transitioning or not _in_game:
		return
	player.teleport_to(world.spawn_point)
	_capture_progress = 0.0
	CaseState.add_divergence(2.0)
	ui.toast("Recuperación de seguridad: saliste del área operativa o caíste al canal. El ancla te devuelve al punto de llegada.", true)
	persist_game(false)


func persist_game(show_notice: bool = true) -> bool:
	if not _in_game or _transitioning or not is_instance_valid(player):
		return false
	var snapshot := player.snapshot()
	if is_instance_valid(world.suspect):
		snapshot["suspect"] = world.suspect.navigation_snapshot()
	var result: Dictionary = CaseState.save_game(snapshot)
	if bool(result["ok"]) and show_notice:
		ui.toast(String(result["message"]))
	return bool(result["ok"])


func _case_changed() -> void:
	if is_instance_valid(world):
		world.sync_case_state()
	if not _suppress_autosave and not _transitioning and _in_game:
		persist_game(false)


func _preferences_changed() -> void:
	if is_instance_valid(world):
		world.apply_quality()


func _result(result: Dictionary) -> void:
	if bool(result["ok"]):
		ui.toast(String(result["message"]))


func _notify(message: String, error: bool) -> void:
	if is_instance_valid(ui):
		ui.toast(message, error)
		if error:
			Soundscape.play_ui("error")


func _return_to_menu() -> void:
	if not persist_game(false):
		return
	_in_game = false
	ui.show_menu()


func _quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	while _transitioning:
		await get_tree().process_frame
	if _in_game and not persist_game(false):
		_quitting = false
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	Soundscape.stop_all()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


func _exit_tree() -> void:
	AssetLibrary.release_cached_resources()
