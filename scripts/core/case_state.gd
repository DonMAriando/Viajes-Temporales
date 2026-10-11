extends Node

signal changed
signal evidence_added(id: String)
signal notification(message: String, is_error: bool)
signal zone_changed(zone: String)
signal divergence_updated(value: float)

const SAVE_VERSION := 1
const CASE_PATH := "res://data/cases/case_001.json"
const PHASES := ["briefing", "ready", "investigation", "chase", "stabilization", "return", "debrief", "complete"]

var save_path: String = "user://case_001.json"
var case_data: Dictionary = {}
var evidence_index: Dictionary = {}
var suspect_index: Dictionary = {}
var deduction_index: Dictionary = {}

var active: bool = false
var zone: String = "hub"
var phase: String = "briefing"
var collected: Array[String] = []
var analyzed: Array[String] = []
var solved: Array[String] = []
var read_articles: Array[String] = []
var dialogue_seen: Array[String] = []
var mistakes: Array[String] = []
var rapport: Dictionary = {}
var selected_suspect: String = ""
var warrant_suspect: String = ""
var rumor_resolved: bool = false
var rumor_checked: bool = false
var neutralized: bool = false
var captured: bool = false
var repaired: bool = false
var completed: bool = false
var chase_active: bool = false
var chase_attempts: int = 0
var divergence: float = 12.0
var peak_divergence: float = 12.0
var field_seconds: float = 0.0
var chase_seconds: float = 0.0
var alternate_line: bool = false
var checkpoint: Dictionary = {}
var _divergence_signal_timer: float = 0.0


func _ready() -> void:
	var file := FileAccess.open(CASE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se puede abrir el Caso 001: %s" % error_string(FileAccess.get_open_error()))
		get_tree().quit(1)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_error("Datos del caso inválidos: %s, línea %s." % [parser.get_error_message(), parser.get_error_line()])
		get_tree().quit(1)
		return
	case_data = parser.data
	for entry: Dictionary in case_data["evidence"]:
		evidence_index[String(entry["id"])] = entry
	for entry: Dictionary in case_data["suspects"]:
		suspect_index[String(entry["id"])] = entry
	for entry: Dictionary in case_data["deductions"]:
		deduction_index[String(entry["id"])] = entry


func _physics_process(delta: float) -> void:
	if not active or completed or zone != "egypt":
		return
	field_seconds += delta
	if not neutralized:
		divergence = minf(100.0, divergence + delta * (0.055 if chase_active else 0.018))
	peak_divergence = maxf(peak_divergence, divergence)
	if divergence >= 60.0 and not alternate_line:
		alternate_line = true
		notification.emit("Línea Beta detectada. Detén el resonador para impedir nuevas alteraciones.", true)
		changed.emit()
	if chase_active:
		chase_seconds += delta
		if chase_seconds >= 95.0:
			chase_active = false
			chase_attempts += 1
			phase = "investigation"
			add_divergence(9.0)
			notification.emit("Contacto perdido. El ancla bloquea su salto: vuelve a localizarlo y reintenta la captura.", true)
			changed.emit()
	_divergence_signal_timer += delta
	if _divergence_signal_timer >= 0.25:
		_divergence_signal_timer = 0.0
		divergence_updated.emit(divergence)


func begin_case() -> void:
	active = true
	zone = "hub"
	phase = "briefing"
	collected.clear()
	analyzed.clear()
	solved.clear()
	read_articles.clear()
	dialogue_seen.clear()
	mistakes.clear()
	rapport.clear()
	selected_suspect = ""
	warrant_suspect = ""
	rumor_resolved = false
	rumor_checked = false
	neutralized = false
	captured = false
	repaired = false
	completed = false
	chase_active = false
	chase_attempts = 0
	divergence = 12.0
	peak_divergence = 12.0
	field_seconds = 0.0
	chase_seconds = 0.0
	alternate_line = false
	checkpoint.clear()
	changed.emit()


func evidence(id: String) -> Dictionary:
	return evidence_index.get(id, {})


func is_evidence_ready(id: String) -> bool:
	if not collected.has(id):
		return false
	var entry := evidence(id)
	return not bool(entry.get("needs_analysis", false)) or analyzed.has(id)


func collect_evidence(id: String) -> Dictionary:
	if not evidence_index.has(id):
		return _reject("La evidencia no existe: %s." % id, true)
	if not active or completed:
		return _reject("No hay una investigación activa.")
	if collected.has(id):
		return _reject("Esta evidencia ya está en tu expediente.")
	collected.append(id)
	if not bool(evidence(id).get("needs_analysis", false)):
		analyzed.append(id)
	if id == "boatman" and rumor_checked:
		rumor_resolved = true
	evidence_added.emit(id)
	notification.emit("Evidencia registrada: %s." % evidence(id)["title"], false)
	changed.emit()
	return _success("Evidencia incorporada al expediente.")


func analyze_evidence(id: String) -> Dictionary:
	if not evidence_index.has(id):
		return _reject("La evidencia no existe: %s." % id, true)
	if not collected.has(id):
		return _reject("Primero debes recuperar esta evidencia.")
	if analyzed.has(id):
		return _reject("Esta evidencia ya está analizada.")
	analyzed.append(id)
	changed.emit()
	return _success(String(evidence(id)["analysis"]))


func deduction_available(id: String) -> bool:
	if not deduction_index.has(id):
		return false
	for required: String in deduction_index[id]["requires"]:
		if not is_evidence_ready(required):
			return false
	return true


func solve_deduction(id: String, option_id: String) -> Dictionary:
	if not deduction_index.has(id):
		return _reject("La deducción no existe: %s." % id, true)
	if solved.has(id):
		return _reject("Esta conclusión ya está confirmada.")
	if not deduction_available(id):
		return _reject("Recupera y analiza las pruebas indicadas antes de concluir.")
	var entry: Dictionary = deduction_index[id]
	var option: Dictionary = {}
	for candidate: Dictionary in entry["options"]:
		if String(candidate["id"]) == option_id:
			option = candidate
			break
	if option.is_empty():
		return _reject("La respuesta no forma parte de esta deducción.", true)
	if not bool(option["correct"]):
		var key := "%s:%s" % [id, option_id]
		if not mistakes.has(key):
			mistakes.append(key)
			add_divergence(1.5)
			changed.emit()
		return _reject("Las pruebas no respaldan esa conclusión. Revisa sus análisis, no solo los títulos.")
	solved.append(id)
	if id == "destination":
		phase = "ready"
	if id == "corroboration":
		rumor_resolved = collected.has("boatman")
	changed.emit()
	return _success(String(entry["explanation"]))


func talk(npc_id: String, topic_id: String) -> Dictionary:
	var dialogues: Dictionary = case_data.get("dialogues", {})
	if not dialogues.has(npc_id):
		return _reject("Interlocutor desconocido.", true)
	var topic: Dictionary = {}
	for candidate: Dictionary in dialogues[npc_id]["topics"]:
		if String(candidate["id"]) == topic_id:
			topic = candidate
			break
	if topic.is_empty():
		return _reject("Tema de conversación desconocido.", true)
	if int(rapport.get(npc_id, 0)) < int(topic.get("requires_rapport", 0)):
		return _reject("Primero explica tus intenciones. El testigo necesita confiar en ti.")
	var key := "%s:%s" % [npc_id, topic_id]
	if not dialogue_seen.has(key):
		dialogue_seen.append(key)
		rapport[npc_id] = int(rapport.get(npc_id, 0)) + int(topic.get("rapport", 0))
		if topic.has("evidence"):
			var evidence_id := String(topic["evidence"])
			if not collected.has(evidence_id):
				collect_evidence(evidence_id)
		if topic.has("resolve"):
			rumor_checked = true
			rumor_resolved = collected.has("boatman")
		changed.emit()
	return _success(String(topic["answer"]))


func read_article(id: String) -> void:
	for article: Dictionary in case_data["archive"]:
		if String(article["id"]) == id:
			if not read_articles.has(id):
				read_articles.append(id)
				changed.emit()
			return
	_reject("Artículo desconocido: %s." % id, true)


func scores(suspect_id: String) -> Dictionary:
	var result := {"identity": 0, "location": 0, "motive": 0}
	for evidence_id: String in collected:
		if not is_evidence_ready(evidence_id):
			continue
		var entry := evidence(evidence_id)
		if String(entry["reliability"]) == "Dudosa":
			continue
		var contribution: Dictionary = entry.get("scores", {}).get(suspect_id, {})
		for category: String in result:
			result[category] = mini(100, int(result[category]) + int(contribution.get(category, 0)))
	return result


func select_suspect(id: String) -> Dictionary:
	if not suspect_index.has(id):
		return _reject("Sospechoso desconocido.", true)
	if not warrant_suspect.is_empty() and warrant_suspect != id:
		return _reject("La orden emitida pertenece a otra persona.")
	selected_suspect = id
	changed.emit()
	return _success("Hipótesis seleccionada: %s. Las barras miden respaldo probatorio, no certeza absoluta." % suspect_index[id]["name"])


func request_warrant() -> Dictionary:
	if selected_suspect.is_empty():
		return _reject("Selecciona un sospechoso y contrasta su ficha.")
	if zone != "egypt":
		return _reject("La orden requiere pruebas recogidas en el escenario histórico.")
	if not warrant_suspect.is_empty():
		return _reject("La orden de captura ya está autorizada.")
	for required: String in ["corroboration", "sabotage", "route"]:
		if not solved.has(required):
			return _reject("Falta una conclusión: %s." % deduction_index[required]["title"])
	var support := scores(selected_suspect)
	var thresholds: Dictionary = case_data["warrant_thresholds"]
	for category: String in thresholds:
		if int(support[category]) < int(thresholds[category]):
			return _reject("Respaldo insuficiente. Identidad, ubicación y motivo deben superar los umbrales de autorización.")
	if not bool(suspect_index[selected_suspect]["correct"]):
		return _reject("Las pruebas son incompatibles con la identidad seleccionada.")
	warrant_suspect = selected_suspect
	changed.emit()
	notification.emit("Orden autorizada. Localiza al sospechoso en el almacén oriental.", false)
	return _success("Captura no letal autorizada. El ancla impedirá un salto temporal durante la persecución.")


func travel_to_egypt() -> Dictionary:
	if not active or zone != "hub" or completed:
		return _reject("El dispositivo no puede iniciar ese viaje ahora.")
	if not solved.has("destination"):
		return _reject("Primero reconstruye el destino en el expediente.")
	zone = "egypt"
	phase = "investigation"
	checkpoint.clear()
	zone_changed.emit(zone)
	changed.emit()
	return _success("Ventana establecida: Guiza, c. 2560 a. C.")


func neutralize_device() -> Dictionary:
	if zone != "egypt":
		return _reject("Debes estar junto al resonador.")
	if not collected.has("device") or not analyzed.has("device") or not solved.has("sabotage"):
		return _reject("Recupera su registro, analízalo y demuestra el sabotaje antes de intervenir.")
	if neutralized:
		return _reject("El resonador ya está desconectado.")
	neutralized = true
	divergence = maxf(0.0, divergence - 5.0)
	changed.emit()
	divergence_updated.emit(divergence)
	return _success("Resonador desconectado sin dañar los soportes. La divergencia deja de crecer.")


func begin_chase() -> Dictionary:
	if zone != "egypt" or captured:
		return _reject("No hay un fugitivo que detener aquí.")
	if warrant_suspect.is_empty():
		return _reject("No puedes detener a una persona sin una orden respaldada por pruebas.")
	if chase_active:
		return _success("Mantén E mientras estés cerca y tengas al fugitivo a la vista.")
	chase_active = true
	chase_seconds = 0.0
	phase = "chase"
	changed.emit()
	return _success("¡El sospechoso huye hacia el canal! Acércate y mantén E para inmovilizarlo sin armas.")


func capture_suspect() -> Dictionary:
	if not chase_active or warrant_suspect.is_empty() or zone != "egypt":
		return _reject("La captura no cumple el protocolo de autorización.")
	captured = true
	chase_active = false
	phase = "stabilization"
	changed.emit()
	return _success("Marcus Vale bajo custodia. Desconecta el resonador y estabiliza el ancla antes de regresar.")


func repair_timeline() -> Dictionary:
	if zone != "egypt" or not captured or not neutralized:
		return _reject("Primero captura al responsable y desconecta el resonador.")
	if repaired:
		return _reject("El ancla ya está estabilizada.")
	repaired = true
	divergence = 6.0 if alternate_line else 0.0
	phase = "return"
	changed.emit()
	divergence_updated.emit(divergence)
	return _success("Ancla estabilizada. Regresa al centro para comparar la línea temporal.")


func return_to_hub() -> Dictionary:
	if zone != "egypt" or not captured or not neutralized or not repaired:
		return _reject("El regreso seguro requiere captura, resonador desconectado y ancla estabilizada.")
	zone = "hub"
	phase = "debrief"
	checkpoint.clear()
	zone_changed.emit(zone)
	changed.emit()
	return _success("Regreso completado. Consulta la consola central para cerrar el expediente.")


func complete_case() -> Dictionary:
	if zone != "hub" or phase != "debrief" or not captured or not repaired or not neutralized:
		return _reject("El caso aún no está listo para su cierre.")
	completed = true
	phase = "complete"
	changed.emit()
	return _success("Caso 001 cerrado. El registro Asterión queda incorporado a la investigación.")


func add_divergence(amount: float) -> void:
	divergence = clampf(divergence + amount, 0.0, 100.0)
	peak_divergence = maxf(peak_divergence, divergence)
	if divergence >= 60.0:
		alternate_line = true
	divergence_updated.emit(divergence)


func objective() -> String:
	if completed:
		return "Expediente cerrado. El pasado vuelve a tener futuro."
	if zone == "hub":
		if phase == "debrief":
			return "Consulta la consola central y compara la línea temporal."
		for id: String in ["alloy", "travel_log", "intercept"]:
			if not collected.has(id):
				return "Examina el laboratorio, los archivos y la mesa de comunicaciones."
			if not analyzed.has(id):
				return "Analiza las pruebas del presente en el expediente [Tab]."
		if not solved.has("destination"):
			return "Reconstruye el destino con las pruebas analizadas [Tab]."
		return "Activa el dispositivo temporal de la sala central."
	if captured:
		if not neutralized:
			return "Desconecta el resonador junto a la rampa de obra."
		if not repaired:
			return "Estabiliza el ancla en el punto de llegada."
		return "Activa el ancla y regresa al centro de operaciones."
	if chase_active:
		return "Captura no letal: mantén E cerca del fugitivo, con visión directa."
	if not solved.has("corroboration"):
		return "Habla con Menna en el mercado. Contrasta su relato con el pago."
	if not solved.has("sabotage"):
		return "Consulta a Hori en la obra y examina el mecanismo bajo la rampa."
	if not solved.has("route"):
		return "Contrasta el registro de Nefer con las huellas del almacén oriental."
	if warrant_suspect.is_empty():
		return "Selecciona al sospechoso y solicita una orden fundada [Tab]."
	return "Localiza a Marcus Vale cerca del almacén oriental. No uses fuerza letal."


func report() -> Dictionary:
	var grade := "A"
	if alternate_line:
		grade = "C"
	elif mistakes.size() > 2 or chase_attempts > 0:
		grade = "B"
	elif collected.size() == evidence_index.size() and mistakes.is_empty() and peak_divergence < 30.0:
		grade = "S"
	return {
		"grade": grade,
		"line": "Beta estabilizada" if alternate_line else "Alpha restaurada",
		"summary": "La obra continúa. Queda una alteración residual documentada para el equipo de reparación." if alternate_line else "La obra continúa sin introducir tecnología ajena a su época.",
		"clues": collected.size(),
		"total_clues": evidence_index.size(),
		"seconds": int(field_seconds),
		"peak": peak_divergence,
		"mistakes": mistakes.size(),
		"attempts": chase_attempts + 1,
		"epilogue": "El resonador guarda un contrato firmado por Asterión. Su protocolo utiliza claves de MERIDIAN. La tecnología no nació donde creíamos."
	}


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")


func save_game(snapshot: Dictionary = {}) -> Dictionary:
	if not active:
		return _reject("No hay un caso activo para guardar.")
	checkpoint = snapshot.duplicate(true)
	var payload := {
		"version": SAVE_VERSION, "case_id": case_data["id"], "zone": zone, "phase": phase,
		"collected": collected, "analyzed": analyzed, "solved": solved,
		"read_articles": read_articles, "dialogue_seen": dialogue_seen, "mistakes": mistakes,
		"rapport": rapport, "selected_suspect": selected_suspect, "warrant_suspect": warrant_suspect,
		"rumor_resolved": rumor_resolved, "rumor_checked": rumor_checked, "neutralized": neutralized,
		"captured": captured, "repaired": repaired, "completed": completed, "chase_active": chase_active,
		"chase_attempts": chase_attempts, "divergence": divergence, "peak_divergence": peak_divergence,
		"field_seconds": field_seconds, "chase_seconds": chase_seconds, "alternate_line": alternate_line,
		"checkpoint": checkpoint
	}
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _reject("No se pudo escribir la partida: %s." % error_string(FileAccess.get_open_error()), true)
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _reject("Error al escribir la partida: %s." % error_string(write_error), true)
	var absolute := ProjectSettings.globalize_path(save_path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup):
			var remove_error := DirAccess.remove_absolute(backup)
			if remove_error != OK:
				return _reject("No se pudo actualizar la copia de seguridad: %s." % error_string(remove_error), true)
		var backup_error := DirAccess.rename_absolute(absolute, backup)
		if backup_error != OK:
			return _reject("No se pudo conservar la partida anterior: %s." % error_string(backup_error), true)
	var commit_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	if commit_error != OK:
		if FileAccess.file_exists(backup):
			var restore_error := DirAccess.rename_absolute(backup, absolute)
			if restore_error != OK:
				push_error("No se pudo restaurar la copia de seguridad: %s." % error_string(restore_error))
		return _reject("No se pudo finalizar el guardado: %s." % error_string(commit_error), true)
	return _success("Partida guardada.")


func load_game() -> Dictionary:
	var result := _read_save(save_path)
	var recovered := false
	if not bool(result["ok"]) and FileAccess.file_exists(save_path + ".bak"):
		result = _read_save(save_path + ".bak")
		recovered = bool(result["ok"])
	if not bool(result["ok"]):
		return _reject(String(result["message"]))
	var payload: Dictionary = result["payload"]
	zone = String(payload["zone"])
	phase = String(payload["phase"])
	collected.assign(payload["collected"])
	analyzed.assign(payload["analyzed"])
	solved.assign(payload["solved"])
	read_articles.assign(payload["read_articles"])
	dialogue_seen.assign(payload["dialogue_seen"])
	mistakes.assign(payload["mistakes"])
	rapport = payload["rapport"].duplicate()
	selected_suspect = String(payload["selected_suspect"])
	warrant_suspect = String(payload["warrant_suspect"])
	rumor_resolved = bool(payload["rumor_resolved"])
	rumor_checked = bool(payload["rumor_checked"])
	neutralized = bool(payload["neutralized"])
	captured = bool(payload["captured"])
	repaired = bool(payload["repaired"])
	completed = bool(payload["completed"])
	chase_active = bool(payload["chase_active"])
	chase_attempts = int(payload["chase_attempts"])
	divergence = float(payload["divergence"])
	peak_divergence = float(payload["peak_divergence"])
	field_seconds = float(payload["field_seconds"])
	chase_seconds = float(payload["chase_seconds"])
	alternate_line = bool(payload["alternate_line"])
	checkpoint = payload["checkpoint"].duplicate(true)
	active = true
	changed.emit()
	return _success("Se recuperó la copia de seguridad de la partida." if recovered else "Partida cargada.")


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "No hay una partida guardada."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "No se pudo leer la partida: %s." % error_string(FileAccess.get_open_error())}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"ok": false, "message": "La partida está dañada. No se sobrescribirá con datos vacíos."}
	var payload: Dictionary = parser.data
	var error := _validate_save(payload)
	if not error.is_empty():
		return {"ok": false, "message": error}
	return {"ok": true, "payload": payload}


func _validate_save(payload: Dictionary) -> String:
	if int(payload.get("version", -1)) != SAVE_VERSION or payload.get("case_id", "") != case_data["id"]:
		return "La partida pertenece a otro caso o a una versión incompatible."
	if payload.get("zone", "") not in ["hub", "egypt"] or payload.get("phase", "") not in PHASES:
		return "La partida contiene una ubicación o fase inválida."
	var arrays := ["collected", "analyzed", "solved", "read_articles", "dialogue_seen", "mistakes"]
	for key: String in arrays:
		if not payload.get(key) is Array:
			return "La partida no contiene una lista válida: %s." % key
		for value: Variant in payload[key]:
			if not value is String:
				return "La partida contiene identificadores inválidos."
	for id: String in payload["collected"]:
		if not evidence_index.has(id):
			return "La partida hace referencia a una evidencia desconocida."
	for id: String in payload["analyzed"]:
		if not payload["collected"].has(id):
			return "La partida contiene análisis sin evidencia recuperada."
	for id: String in payload["solved"]:
		if not deduction_index.has(id):
			return "La partida contiene una conclusión desconocida."
	for key: String in ["rumor_resolved", "rumor_checked", "neutralized", "captured", "repaired", "completed", "chase_active", "alternate_line"]:
		if not payload.get(key) is bool:
			return "La partida contiene un estado inválido: %s." % key
	for key: String in ["divergence", "peak_divergence", "field_seconds", "chase_seconds", "chase_attempts"]:
		var value: Variant = payload.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0:
			return "La partida contiene una medida inválida: %s." % key
	if float(payload["divergence"]) > 100.0 or float(payload["peak_divergence"]) > 100.0:
		return "La divergencia guardada está fuera de sus límites."
	if not payload.get("rapport") is Dictionary or not payload.get("checkpoint") is Dictionary:
		return "La partida no contiene un punto de control válido."
	for key: String in ["selected_suspect", "warrant_suspect"]:
		if not payload.get(key) is String or (not String(payload[key]).is_empty() and not suspect_index.has(payload[key])):
			return "La partida contiene una identidad inválida."
	if bool(payload["captured"]) and String(payload["warrant_suspect"]).is_empty():
		return "La partida contiene una captura sin autorización."
	if bool(payload["repaired"]) and (not bool(payload["captured"]) or not bool(payload["neutralized"])):
		return "La partida contiene una reparación sin completar el protocolo."
	if bool(payload["completed"]) and (not bool(payload["repaired"]) or payload["zone"] != "hub"):
		return "La partida contiene un cierre de caso incompleto."
	if bool(payload["chase_active"]) and (payload["zone"] != "egypt" or bool(payload["captured"]) or String(payload["warrant_suspect"]).is_empty()):
		return "La partida contiene una persecución incompatible con el caso."
	return ""


func _success(message: String) -> Dictionary:
	return {"ok": true, "message": message}


func _reject(message: String, unexpected: bool = false) -> Dictionary:
	if unexpected:
		push_error(message)
	notification.emit(message, true)
	return {"ok": false, "message": message}
