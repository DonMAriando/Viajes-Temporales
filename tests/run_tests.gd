extends Node

var _checks: int = 0
var _failures: Array[String] = []
var _state: Node
var _main: Node3D
var _path := "user://verification/case_001_test.json"
@onready var _tree: SceneTree = get_tree()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("FAIL: " + description)


func _run() -> void:
	await _tree.process_frame
	var version := Engine.get_version_info()
	_check(version["major"] == 4 and version["minor"] == 7 and version["patch"] == 2, "El motor es exactamente Godot 4.7.2.")
	_state = _tree.root.get_node("CaseState")
	_state.save_path = _path
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://verification"))
	_check(directory_error == OK, "El directorio de pruebas puede crearse.")
	_cleanup_save()
	_test_investigation_rules()
	_test_persistence()
	_test_alternate_line()
	await _test_playable_scene()
	_tree.root.get_node("Soundscape").stop_all()
	if is_instance_valid(_main):
		_main.queue_free()
		await _tree.process_frame
		await _tree.process_frame
	_cleanup_save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_tree.paused = false
	# Fixed-fps verification advances faster than the asynchronous audio mixer.
	OS.delay_msec(150)
	print("MERIDIAN: %s comprobaciones; %s fallos." % [_checks, _failures.size()])
	if not _failures.is_empty():
		for failure: String in _failures:
			printerr(" - " + failure)
	_tree.quit(0 if _failures.is_empty() else 1)


func _test_investigation_rules() -> void:
	_state.begin_case()
	_check(_state.evidence_index.size() == 10, "El caso contiene diez fuentes de evidencia definidas.")
	_check(not _state.travel_to_egypt()["ok"], "No se viaja sin deducir el destino.")
	_check(not _state.capture_suspect()["ok"], "No se captura sin orden y persecución.")
	_check(not _state.repair_timeline()["ok"], "No se repara sin captura y neutralización.")
	_check(_state.collect_evidence("alloy")["ok"], "Se registra una prueba física.")
	_check(not _state.collect_evidence("alloy")["ok"] and _state.collected.size() == 1, "Una evidencia no se duplica.")
	_check(not _state.deduction_available("destination"), "Una muestra sin analizar no respalda una conclusión.")
	for id: String in ["alloy", "travel_log", "intercept"]:
		if not _state.collected.has(id):
			_state.collect_evidence(id)
		_check(_state.analyze_evidence(id)["ok"], "El análisis de %s se incorpora." % id)
	var before: float = _state.divergence
	_check(not _state.solve_deduction("destination", "alexandria")["ok"], "Se rechaza un destino anacrónico.")
	_check(is_equal_approx(_state.divergence, before + 1.5), "Una conclusión errónea deja una consecuencia medida.")
	_state.solve_deduction("destination", "alexandria")
	_check(is_equal_approx(_state.divergence, before + 1.5), "Repetir la misma respuesta no acumula castigos artificiales.")
	_check(_state.solve_deduction("destination", "giza")["ok"], "La evidencia permite reconstruir Guiza.")
	_check(_state.travel_to_egypt()["ok"] and _state.zone == "egypt", "La deducción habilita el viaje correcto.")
	_check(not _state.talk("merchant", "stranger")["ok"], "El testigo exige confianza antes de declarar.")
	_state.talk("merchant", "intro")
	_state.talk("merchant", "intro")
	_check(_state.rapport["merchant"] == 1, "La confianza no se obtiene repitiendo un saludo.")
	_check(_state.talk("merchant", "stranger")["ok"], "El testigo aporta una descripción tras la presentación.")
	_state.collect_evidence("payment")
	_state.analyze_evidence("payment")
	_check(_state.solve_deduction("corroboration", "metal")["ok"], "La prueba física corrobora el relato.")
	_state.talk("boatman", "rumor")
	_state.talk("scribe", "delivery")
	_state.talk("scribe", "rumor")
	_check(_state.rumor_resolved, "El rumor contradictorio se descarta mediante registro y testimonio.")
	_check(_state.scores("soren")["identity"] == 0, "Un rumor no añade respaldo a una detención.")
	_state.talk("builder", "box")
	_state.collect_evidence("device")
	_state.analyze_evidence("device")
	_check(not _state.neutralize_device()["ok"], "No se interviene un dispositivo sin demostrar su función.")
	_check(_state.solve_deduction("sabotage", "fracture")["ok"], "El registro del dispositivo prueba el sabotaje.")
	_state.collect_evidence("route")
	_state.analyze_evidence("route")
	_check(not _state.solve_deduction("route", "horse")["ok"], "La reconstrucción rechaza caballos anacrónicos.")
	_check(_state.solve_deduction("route", "canal")["ok"], "Los registros y las huellas reconstruyen la retirada.")
	_state.select_suspect("soren")
	_check(not _state.request_warrant()["ok"], "No se autoriza una persona incompatible con las pruebas.")
	_state.select_suspect("vale")
	var scores: Dictionary = _state.scores("vale")
	var thresholds: Dictionary = _state.case_data["warrant_thresholds"]
	for category: String in thresholds:
		_check(scores[category] >= thresholds[category], "El respaldo de %s alcanza el umbral real." % category)
	_check(_state.request_warrant()["ok"], "La orden exige las tres conclusiones y los umbrales probatorios.")
	_check(_state.neutralize_device()["ok"], "El resonador puede desconectarse de manera fundada.")
	before = _state.divergence
	_state._physics_process(30.0)
	_check(is_equal_approx(_state.divergence, before), "La neutralización detiene el crecimiento de divergencia.")
	_check(_state.begin_chase()["ok"], "La orden habilita la persecución.")
	_state._physics_process(96.0)
	_check(not _state.chase_active and _state.chase_attempts == 1, "El contacto perdido no deja el caso bloqueado.")
	_check(_state.begin_chase()["ok"], "Es posible reintentar una persecución fallida.")
	_check(_state.capture_suspect()["ok"], "La captura autorizada conserva al detenido con vida.")
	_check(not _state.return_to_hub()["ok"], "El regreso exige estabilizar el ancla.")
	_check(_state.repair_timeline()["ok"], "La reparación requiere al responsable bajo custodia.")
	_check(_state.return_to_hub()["ok"] and _state.phase == "debrief", "El regreso conduce al análisis del presente.")
	_check(_state.complete_case()["ok"] and _state.completed, "El expediente se cierra solo al completar todo el ciclo.")
	_check(_state.report()["grade"] == "B", "El informe refleja errores y el intento fallido.")


func _test_persistence() -> void:
	var snapshot := {"position": [0.0, 0.0, 8.0], "yaw": 0.0, "pitch": 0.0, "stamina": 80.0}
	_check(_state.save_game(snapshot)["ok"], "El guardado escribe el estado completo.")
	var original_seconds: float = _state.field_seconds
	_state.begin_case()
	_check(_state.load_game()["ok"] and _state.completed, "La carga restaura un expediente cerrado.")
	_check(_state.collected.size() == 10 and _state.solved.size() == 4 and _state.warrant_suspect == "vale", "Las pruebas, deducciones y autorización sobreviven a la carga.")
	_check(is_equal_approx(_state.field_seconds, original_seconds), "El tiempo de campo no se reinicia al cargar.")
	_check(_state.checkpoint["stamina"] == 80.0, "El punto de control conserva la resistencia.")
	_state.save_game(snapshot)
	_check(FileAccess.file_exists(_path + ".bak"), "Existe una copia de seguridad del último guardado.")
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{ damaged")
	file.close()
	_check(_state.load_game()["ok"] and _state.completed, "Un archivo dañado recupera la copia válida.")
	file = FileAccess.open(_path + ".bak", FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	_check(not _state.load_game()["ok"] and _state.completed, "La corrupción de ambas copias se notifica sin vaciar el progreso en memoria.")
	var invalid := {"version": 500, "case_id": "case_001"}
	_check(not _state._validate_save(invalid).is_empty(), "Se rechazan versiones incompatibles.")


func _test_alternate_line() -> void:
	_state.begin_case()
	_prepare_present()
	_state.travel_to_egypt()
	_prepare_field()
	_state.add_divergence(55.0)
	_check(_state.alternate_line and _state.divergence >= 60.0, "La divergencia genera una línea alternativa real.")
	_state.select_suspect("vale")
	_state.request_warrant()
	_state.neutralize_device()
	_state.begin_chase()
	_state.capture_suspect()
	_state.repair_timeline()
	_check(is_equal_approx(_state.divergence, 6.0), "La línea Beta conserva una alteración residual después de estabilizarse.")
	_state.return_to_hub()
	_state.complete_case()
	_check(_state.report()["grade"] == "C" and _state.report()["line"] == "Beta estabilizada", "El cierre distingue la línea alternativa de Alpha.")


func _prepare_present() -> void:
	for id: String in ["alloy", "travel_log", "intercept"]:
		_state.collect_evidence(id)
		_state.analyze_evidence(id)
	_state.solve_deduction("destination", "giza")


func _prepare_field() -> void:
	_state.talk("merchant", "intro")
	_state.talk("merchant", "stranger")
	_state.talk("scribe", "delivery")
	_state.talk("builder", "box")
	for id: String in ["payment", "device", "route"]:
		_state.collect_evidence(id)
		_state.analyze_evidence(id)
	_state.solve_deduction("corroboration", "metal")
	_state.solve_deduction("sabotage", "fracture")
	_state.solve_deduction("route", "canal")


func _test_playable_scene() -> void:
	_state.begin_case()
	_tree.root.get_node("Preferences").quality = 0
	var scene: PackedScene = load("res://scenes/main.tscn")
	_main = scene.instantiate()
	_tree.root.add_child(_main)
	await _tree.process_frame
	_check(_main.ui.overlay_kind == "menu" and _tree.paused, "El menú aparece sobre el centro y pausa la simulación.")
	var body_font := _main.ui._root.theme.default_font as FontVariation
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	_check(body_font.variation_opentype.get(weight_axis) == 500.0, "La interfaz configura un peso medio con la etiqueta OpenType nativa.")
	_check(body_font.get_string_size("Investigar el pasado.", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x > body_font.base_font.get_string_size("Investigar el pasado.", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x, "El motor aplica el peso de la fuente y no el estilo ExtraLight por defecto.")
	await _main._start_new_case()
	_check(_main.ui.overlay_kind == "briefing", "Un caso nuevo presenta el briefing.")
	_main.ui.close_overlay()
	await _frames(8)
	_check(not _tree.paused and _main.player.controls_enabled, "Aceptar la misión activa los controles.")
	_test_agency_entrance()
	var start: Vector3 = _main.player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	_check(start.distance_to(_main.player.global_position) > 0.8, "W desplaza al agente sobre la geometría real.")
	await _frames(12)
	_check(Vector2(_main.player.velocity.x, _main.player.velocity.z).length() < 0.1, "La desaceleración elimina la deriva al soltar el movimiento.")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(24)
	_check(_main.player.stamina < 100.0 and _main.player.sprinting, "Correr consume resistencia en tiempo de física.")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(12)
	Input.action_press("crouch")
	await _frames(30)
	_check(_main.player.crouching and _main.player.collider.shape.height <= 1.13, "Agacharse modifica el volumen físico, no solo la cámara.")
	var ceiling := StaticBody3D.new()
	var ceiling_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.2, 2.0)
	ceiling_shape.shape = box
	ceiling.add_child(ceiling_shape)
	ceiling.position = _main.player.global_position + Vector3(0, 1.6, 0)
	_main.world.add_child(ceiling)
	Input.action_release("crouch")
	await _frames(8)
	_check(_main.player.crouching, "Un techo impide levantarse y atravesar geometría.")
	ceiling.queue_free()
	await _frames(35)
	_check(not _main.player.crouching and is_equal_approx(_main.player.collider.shape.height, 1.76), "Al liberar el techo se recupera la altura normal.")
	for id: String in ["alloy", "travel_log", "intercept"]:
		var target := _find_interaction(id)
		_check(target != null, "La escena contiene el punto interactivo %s." % id)
		if target == null:
			continue
		_main.player.teleport_to(target.global_position + Vector3(0, -target.global_position.y, 1.6))
		_aim_at(target.global_position)
		await _frames(10)
		_check(_main.player.focus_target == target, "La línea de visión encuentra %s sin atravesar el mobiliario." % id)
		_press_key(KEY_E)
		await _tree.process_frame
		await _tree.process_frame
		_check(_state.collected.has(id) and _main.ui.overlay_kind == "evidence", "E recoge %s y abre su ficha real (interfaz: %s; pruebas: %s)." % [id, _main.ui.overlay_kind, _state.collected])
		var analyze := _find_button(_main.ui, "Analizar con el equipo forense")
		_check(analyze != null, "La ficha ofrece un análisis funcional.")
		if analyze != null:
			analyze.pressed.emit()
		_release_key(KEY_E)
		_main.ui.close_overlay()
		await _frames(3)
	_main.ui.show_journal("Deducciones")
	await _tree.process_frame
	var destination := _find_button(_main.ui, "Guiza · IV dinastía · c. 2560 a. C.")
	_check(destination != null and not destination.disabled, "El expediente habilita la deducción al analizar las tres pruebas.")
	if destination != null:
		destination.pressed.emit()
	await _tree.process_frame
	_check(_state.solved.has("destination"), "El botón de deducción está conectado al estado del caso.")
	_main.ui.close_overlay()
	_main._interact(_find_interaction("time_gate"))
	await _wait_transition()
	_check(_main.world.zone == "egypt" and _state.zone == "egypt", "El dispositivo cambia realmente a la escena histórica.")
	await _frames(8)
	var field_start: Vector3 = _main.player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	_check(field_start.distance_to(_main.player.global_position) > 0.8 and _main.player.is_on_floor(), "El terreno visible de Guiza también sostiene el desplazamiento físico.")
	await _frames(12)
	_check(_tree.get_nodes_in_group("npcs").size() == 9, "Guiza incluye cuatro testigos, un sospechoso y cuatro trabajadores.")
	var npc: TemporalNPC = _main.world.suspect
	if not is_instance_valid(npc):
		_check(false, "La escena histórica contiene un sospechoso físico.")
		return
	_check(npc.animation_player != null and npc.animation_player.is_playing(), "Los NPC usan animación esquelética activa.")
	var worker: TemporalNPC
	for node: Node in _tree.get_nodes_in_group("npcs"):
		if (node as TemporalNPC).npc_id == "worker_0":
			worker = node as TemporalNPC
	_check(is_instance_valid(worker), "La escena contiene un trabajador con caminata verificable.")
	if is_instance_valid(worker):
		await _frames(100)
		await _check_locomotion(worker, "walk")
		worker.animation_player.seek(worker.animation_player.current_animation_length * 0.38, true)
		worker._play("run")
		_check(absf(worker.animation_player.current_animation_position / worker.animation_player.current_animation_length - 0.38) < 0.001, "Cambiar entre caminar y correr conserva la fase de los pies.")
		worker.conversing = true
		await _frames(18)
		_check(worker._last_animation == "idle" and is_equal_approx(worker.animation_player.speed_scale, 1.0), "Al detenerse el trabajador vuelve al reposo sin seguir caminando sobre el lugar.")
		worker.conversing = false
	var navigation_map := npc.navigation.get_navigation_map()
	_check(NavigationServer3D.map_get_iteration_id(navigation_map) > 0, "El mapa de navegación está sincronizado.")
	var path := NavigationServer3D.map_get_path(navigation_map, npc.spawn_point, Vector3(69, 0, 61), true)
	_check(path.size() >= 2, "El almacén y el embarcadero están conectados por una ruta transitable.")
	if not path.is_empty():
		_check(path[-1].distance_to(Vector3(69, 0.04, 61)) < 1.0, "La ruta calculada alcanza el destino real, no una isla de navegación desconectada.")
		_check(absf(path[-1].y - 0.29) < 0.01, "La navegación respeta la altura física del embarcadero.")
	var seconds: float = _state.field_seconds
	_main.ui.show_pause()
	await _tree.create_timer(0.08).timeout
	_check(is_equal_approx(seconds, _state.field_seconds), "Pausar detiene también el reloj de divergencia.")
	_main.ui.close_overlay()
	_prepare_field()
	_state.select_suspect("vale")
	_state.request_warrant()
	_state.neutralize_device()
	_main.player.teleport_to(npc.global_position + Vector3(0, 0, 2.2))
	_aim_at(npc.global_position + Vector3(0, 1.25, 0))
	await _frames(10)
	_main._interact(npc)
	_check(_state.chase_active, "Interactuar con el sospechoso inicia una persecución autorizada.")
	await _frames(30)
	await _check_locomotion(npc, "run")
	var moved_from: Vector3 = npc.global_position
	for i: int in range(2000):
		if npc.global_position.distance_to(npc.escape_route[-1]) < 1.5:
			break
		await _tree.physics_frame
	_check(npc.global_position.distance_to(moved_from) > 30.0, "El fugitivo recorre físicamente el escenario histórico.")
	_check(npc.global_position.distance_to(npc.escape_route[-1]) < 1.5, "La persecución llega al embarcadero (posición: %s; tramo: %s; objetivo: %s)." % [npc.global_position, npc._route_index, npc.navigation.target_position])
	if npc.global_position.distance_to(npc.escape_route[-1]) >= 1.5:
		for index: int in range(npc.get_slide_collision_count()):
			var collision := npc.get_slide_collision(index)
			var collider := collision.get_collider() as Node3D
			print("NPC_BLOCKER: ", collider.get_path(), " position=", collider.global_position, " normal=", collision.get_normal(), " motion=", collision.get_travel())
	Input.action_press("interact")
	for i: int in range(160):
		if _state.captured:
			break
		var desired := npc.global_position + Vector3(0, 0.05, 2.0)
		_main.player.teleport_to(desired)
		_aim_at(npc.global_position + Vector3(0, 1.25, 0))
		await _tree.physics_frame
	Input.action_release("interact")
	_check(_state.captured and not _state.chase_active, "Mantener E con distancia y visión válidas completa la captura real.")
	_check(_main.persist_game(false), "La escena guarda también la posición y navegación del sospechoso.")
	_main._interact(_find_interaction("field_anchor"))
	_check(_state.repaired, "El ancla de la escena está conectada a la reparación.")
	_main._interact(_find_interaction("field_anchor"))
	await _wait_transition()
	_check(_state.zone == "hub" and _state.phase == "debrief", "El ancla regresa al presente después de cumplir el protocolo.")
	_main._interact(_find_interaction("case_console"))
	_check(_state.completed and _main.ui.overlay_kind == "report", "La consola del presente cierra el caso y muestra sus consecuencias.")
	_main.ui.show_journal("Archivo")
	await _tree.process_frame
	_check(_find_button(_main.ui, "Registrar lectura") != null, "El archivo histórico es consultable desde la interfaz.")
	_main.ui.close_overlay()
	_main.ui.show_settings("pause")
	await _tree.process_frame
	_check(_find_button(_main.ui, "Aplicar y guardar ajustes") != null, "Los ajustes están integrados, no son un botón vacío.")
	_main.ui.close_overlay()
	_main.ui.close_overlay()
	_main._return_to_menu()
	_check(_main.ui.overlay_kind == "menu" and _state.has_save(), "El menú conserva el progreso terminado.")
	await _main._continue_case()
	_check(_state.completed and _main.ui.overlay_kind == "report", "Continuar restaura un caso cerrado sin reiniciarlo.")


func _test_agency_entrance() -> void:
	var door := _main.world.get_node_or_null("AgencyEntrance") as MeshInstance3D
	_check(door != null, "El centro tiene una puerta principal visible en una abertura de la pared.")
	if door == null:
		return
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.3, 10), Vector3(0, 1.3, 13), 1)
	var hit: Dictionary = _main.world.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as StaticBody3D
	_check(collider != null and collider.get_parent() == door, "La puerta cerrada, no una pared superpuesta, bloquea el acceso exterior.")
	var found := false
	for landmark: Dictionary in _main.world.landmarks:
		if landmark["name"] == "Acceso principal":
			found = true
	_check(found, "La entrada aparece entre los puntos de referencia del centro.")


func _check_locomotion(npc: TemporalNPC, action: String) -> void:
	var before := npc.global_position
	await _frames(1)
	var motion := npc.global_position - before
	var actual_speed := Vector2(motion.x, motion.z).length() / npc.get_physics_process_delta_time()
	_check(npc._last_animation == action, "El personaje activa la animación %s durante su desplazamiento." % action)
	var animation := npc.animation_player.get_animation(String(npc._animations[action]))
	var stride := float(npc._stride_lengths[action]) * npc.model.scale.y
	var animated_speed := npc.animation_player.speed_scale * stride / animation.length
	_check(actual_speed > 0.1 and absf(animated_speed - actual_speed) < 0.015, "La zancada %s coincide con la velocidad física y la estatura (animación: %.3f; movimiento: %.3f)." % [action, animated_speed, actual_speed])
	_check(npc.animation_player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS, "La animación avanza en el mismo reloj de física que el personaje.")


func _find_interaction(id: String) -> TemporalInteractable:
	for node: Node in _tree.get_nodes_in_group("interactables"):
		var target := node as TemporalInteractable
		if target.interaction_id == id:
			return target
	return null


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var button := _find_button(child, text)
		if button != null:
			return button
	return null


func _aim_at(point: Vector3) -> void:
	var direction: Vector3 = point - _main.player.camera.global_position
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
	_main.player.teleport_to(_main.player.global_position, yaw, pitch)


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for i: int in range(count):
		await _tree.physics_frame


func _wait_transition() -> void:
	for i: int in range(100):
		if not _main._transitioning:
			return
		await _tree.create_timer(0.05).timeout
	_check(false, "La transición temporal finaliza dentro de cinco segundos.")


func _cleanup_save() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := _path + suffix
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				_failures.append("No se pudo limpiar el archivo de prueba: %s." % path)
