class_name GameUI
extends CanvasLayer

signal overlay_changed(opened: bool)
signal new_case_requested
signal continue_requested
signal menu_requested
signal save_requested
signal quit_requested

const GOLD := Color(0.84, 0.71, 0.48)
const TEXT := Color(0.9, 0.91, 0.87)
const MUTED := Color(0.62, 0.7, 0.7)
const CYAN := Color(0.52, 0.82, 0.84)
const RED := Color(0.93, 0.57, 0.42)

var overlay_kind: String = ""
var current_page: String = "Evidencias"
var world: TemporalWorld
var player: FirstPersonAgent
var _root: Control
var _hud: Control
var _overlay: Control
var _shade: ColorRect
var _objective: Label
var _location: Label
var _phase: Label
var _compass: Label
var _divergence_label: Label
var _divergence_bar: ProgressBar
var _stamina_bar: ProgressBar
var _stamina_panel: Control
var _prompt_panel: Control
var _prompt_label: Label
var _capture_panel: Control
var _capture_bar: ProgressBar
var _scanner_hint: Label
var _toast_panel: Control
var _toast_label: Label
var _toast_timer: float = 0.0
var _page_content: VBoxContainer
var _dialog_response: Label
var _dialog_topics: VBoxContainer
var _dialog_id: String = ""
var _settings_origin: String = "menu"
var _refresh_pending: bool = false
var _font: Font
var _title_font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	var body_font := FontVariation.new()
	body_font.base_font = load("res://assets/fonts/manrope.ttf")
	body_font.variation_opentype = {weight_axis: 500.0}
	_font = body_font
	var heading_font := FontVariation.new()
	heading_font.base_font = load("res://assets/fonts/cinzel.ttf")
	heading_font.variation_opentype = {weight_axis: 500.0}
	_title_font = heading_font
	assert(body_font.base_font != null and heading_font.base_font != null, "Faltan las fuentes del juego.")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_hud()
	_build_toast()
	CaseState.changed.connect(_on_case_changed)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		_toast_panel.modulate.a = clampf(_toast_timer * 3.0, 0.0, 1.0)
		_toast_panel.visible = _toast_timer > 0.0


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.38, 0.45, 0.46))
	theme.set_stylebox("normal", "Button", _style(Color(0.09, 0.13, 0.145), Color(0.23, 0.3, 0.31), 12))
	theme.set_stylebox("hover", "Button", _style(Color(0.15, 0.2, 0.205), GOLD, 12))
	theme.set_stylebox("pressed", "Button", _style(Color(0.19, 0.22, 0.21), GOLD, 12))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), CYAN, 12))
	theme.set_stylebox("disabled", "Button", _style(Color(0.065, 0.09, 0.1), Color(0.13, 0.18, 0.18), 12))
	theme.set_stylebox("panel", "PanelContainer", _style(Color(0.035, 0.063, 0.075, 0.97), Color(0.2, 0.27, 0.285), 20))
	theme.set_stylebox("background", "ProgressBar", _style(Color(0.09, 0.13, 0.14), Color(0.09, 0.13, 0.14), 0))
	theme.set_stylebox("fill", "ProgressBar", _style(GOLD, GOLD, 0))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 16)
	return theme


func _style(background: Color, border: Color, margin: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


func _text(value: String, size: int = 18, color: Color = TEXT, title: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if title:
		label.add_theme_font_override("font", _title_font)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(value: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.disabled = disabled
	button.custom_minimum_size.y = 46
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		Soundscape.play_ui("click")
		action.call()
	)
	return button


func _card(parent: Node, margin: int = 18) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color(0.065, 0.1, 0.115, 0.97), Color(0.2, 0.27, 0.28), margin))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	return column


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var mission := PanelContainer.new()
	mission.position = Vector2(36, 30)
	mission.custom_minimum_size = Vector2(490, 0)
	_hud.add_child(mission)
	var column := VBoxContainer.new()
	mission.add_child(column)
	_phase = _text("MERIDIAN / EXPEDIENTE 001", 13, GOLD)
	_location = _text("Centro de operaciones", 24)
	_objective = _text("", 16, TEXT)
	_objective.custom_minimum_size.x = 440
	column.add_child(_phase)
	column.add_child(_location)
	column.add_child(_objective)
	var compass_panel := PanelContainer.new()
	compass_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass_panel.offset_left = -90
	compass_panel.offset_right = 90
	compass_panel.offset_top = 30
	compass_panel.offset_bottom = 75
	compass_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.05, 0.06, 0.88), Color(0.2, 0.27, 0.28), 8))
	_hud.add_child(compass_panel)
	_compass = _text("N", 17, TEXT)
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_panel.add_child(_compass)
	var temporal := PanelContainer.new()
	temporal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	temporal.position = Vector2(-325, 30)
	temporal.custom_minimum_size = Vector2(285, 106)
	_hud.add_child(temporal)
	var temporal_column := VBoxContainer.new()
	temporal.add_child(temporal_column)
	temporal_column.add_child(_text("INTEGRIDAD CAUSAL", 13, GOLD))
	_divergence_label = _text("Alpha / divergencia 12 %", 16)
	temporal_column.add_child(_divergence_label)
	_divergence_bar = ProgressBar.new()
	_divergence_bar.show_percentage = false
	_divergence_bar.custom_minimum_size = Vector2(240, 5)
	temporal_column.add_child(_divergence_bar)
	var crosshair := _text("·", 32, Color(0.9, 0.94, 0.92, 0.8))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -8
	crosshair.offset_top = -24
	crosshair.offset_right = 8
	crosshair.offset_bottom = 24
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(crosshair)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_left = -350
	_prompt_panel.offset_right = 350
	_prompt_panel.offset_top = -184
	_prompt_panel.offset_bottom = -120
	_hud.add_child(_prompt_panel)
	_prompt_label = _text("", 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)
	_prompt_panel.visible = false
	_capture_panel = VBoxContainer.new()
	_capture_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_capture_panel.offset_left = -210
	_capture_panel.offset_right = 210
	_capture_panel.offset_top = -110
	_capture_panel.offset_bottom = -58
	_hud.add_child(_capture_panel)
	_capture_panel.add_child(_text("INMOVILIZACIÓN NO LETAL", 13, CYAN))
	_capture_bar = ProgressBar.new()
	_capture_bar.max_value = 1.0
	_capture_bar.show_percentage = false
	_capture_bar.custom_minimum_size.y = 6
	_capture_panel.add_child(_capture_bar)
	_capture_panel.visible = false
	_stamina_panel = VBoxContainer.new()
	_stamina_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stamina_panel.position = Vector2(36, -85)
	_stamina_panel.custom_minimum_size = Vector2(210, 40)
	_hud.add_child(_stamina_panel)
	_stamina_panel.add_child(_text("RESISTENCIA", 12, MUTED))
	_stamina_bar = ProgressBar.new()
	_stamina_bar.show_percentage = false
	_stamina_bar.custom_minimum_size = Vector2(210, 4)
	_stamina_panel.add_child(_stamina_bar)
	var hints_panel := PanelContainer.new()
	hints_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hints_panel.offset_left = -560
	hints_panel.offset_right = -36
	hints_panel.offset_top = -64
	hints_panel.offset_bottom = -22
	hints_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.05, 0.06, 0.88), Color(0.2, 0.27, 0.28), 10))
	_hud.add_child(hints_panel)
	_scanner_hint = _text("TAB · expediente     Q · escáner     ESC · pausa", 14, TEXT)
	_scanner_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hints_panel.add_child(_scanner_hint)
	_hud.visible = false


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.z_index = 100
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast_panel.offset_left = -490
	_toast_panel.offset_right = -36
	_toast_panel.offset_top = -220
	_toast_panel.offset_bottom = -105
	_root.add_child(_toast_panel)
	_toast_label = _text("", 16)
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false


func toast(message: String, error: bool = false) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", RED if error else TEXT)
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_timer = 5.0 if error else 3.8


func update_hud(agent: FirstPersonAgent, current_world: TemporalWorld, capture_progress: float, scanner_cooldown: float) -> void:
	player = agent
	world = current_world
	if not is_instance_valid(agent) or not is_instance_valid(world):
		return
	_objective.text = CaseState.objective()
	_location.text = world.location_name(agent.global_position)
	_phase.text = "CASO 001 / " + ("GUIZA · c. 2560 a. C." if CaseState.zone == "egypt" else "MERIDIAN · PRESENTE, %s" % CaseState.case_data["present_year"])
	_divergence_label.text = "%s / divergencia %.0f %%" % ["Beta" if CaseState.alternate_line else "Alpha", CaseState.divergence]
	_divergence_bar.value = CaseState.divergence
	_stamina_bar.value = agent.stamina
	_stamina_panel.visible = agent.stamina < 99.0
	_capture_panel.visible = capture_progress > 0.0
	_capture_bar.value = capture_progress
	var directions := ["N", "NO", "O", "SO", "S", "SE", "E", "NE"]
	var heading := posmod(int(round(agent.rotation.y / TAU * 8.0)), 8)
	_compass.text = "%s  /  %.0f°" % [directions[heading], fposmod(-rad_to_deg(agent.rotation.y), 360.0)]
	_scanner_hint.text = "TAB · expediente     Q · %s     ESC · pausa" % ("escáner" if scanner_cooldown <= 0.0 else "%.0f s" % scanner_cooldown)
	var target := agent.focus_target
	_prompt_panel.visible = is_instance_valid(target)
	if is_instance_valid(target):
		_prompt_label.text = "[ E ]   " + target.prompt()


func _new_overlay(kind: String, shade: bool = true) -> void:
	if is_instance_valid(_overlay):
		_root.remove_child(_overlay)
		_overlay.queue_free()
	overlay_kind = kind
	_hud.visible = false
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)
	if shade:
		_shade = ColorRect.new()
		_shade.color = Color(0.01, 0.025, 0.035, 0.7)
		_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_overlay.add_child(_shade)
	overlay_changed.emit(true)


func close_overlay() -> void:
	if overlay_kind in ["menu", "loading"]:
		return
	if overlay_kind == "confirm":
		show_menu()
		return
	if overlay_kind in ["settings", "controls", "credits"]:
		if _settings_origin == "menu":
			show_menu()
		else:
			show_pause()
		return
	if is_instance_valid(_overlay):
		_root.remove_child(_overlay)
		_overlay.queue_free()
	_overlay = null
	overlay_kind = ""
	_hud.visible = CaseState.active
	_dialog_id = ""
	overlay_changed.emit(false)


func _window(title: String, subtitle: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 86
	panel.offset_top = 72
	panel.offset_right = -86
	panel.offset_bottom = -68
	_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_text(title, 34, GOLD, true))
	if not subtitle.is_empty():
		titles.add_child(_text(subtitle, 15, MUTED))
	var close := _button("Cerrar [Esc]", close_overlay)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 160
	header.add_child(close)
	column.add_child(HSeparator.new())
	return column


func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column


func show_menu() -> void:
	_new_overlay("menu", false)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/menu_shade.gdshader")
	shade.material = material
	_overlay.add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(88, 98)
	panel.size = Vector2(520, 660)
	_overlay.add_child(panel)
	panel.add_child(_text("DIVISIÓN DE DELITOS TEMPORALES", 14, GOLD))
	panel.add_child(_text("MERIDIAN", 62, TEXT, true))
	panel.add_child(_text("A R C H I V O   T E M P O R A L", 17, MUTED))
	panel.add_child(HSeparator.new())
	panel.add_child(_text("Investigar el pasado.\nProteger el futuro.", 26, TEXT))
	panel.add_child(_text("CASO 001 / LA PIRÁMIDE", 14, GOLD))
	panel.add_child(_text("Un crimen que todavía no ha ocurrido.", 18, MUTED))
	panel.add_child(_button("Continuar investigación", func() -> void: continue_requested.emit(), not CaseState.has_save()))
	panel.add_child(_button("Iniciar Caso 001", _confirm_new))
	panel.add_child(_button("Ajustes", func() -> void: show_settings("menu")))
	var row := HBoxContainer.new()
	row.add_child(_button("Controles", func() -> void: show_controls("menu")))
	row.add_child(_button("Créditos", func() -> void: show_credits("menu")))
	panel.add_child(row)
	panel.add_child(_button("Salir", func() -> void: quit_requested.emit()))
	var footer := _text("PRIMERA PERSONA  /  GODOT 4.7.2  /  RECURSOS CC0\nReconstrucción artística de Guiza; crimen y viajeros ficticios.", 13, MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(88, -66)
	footer.custom_minimum_size.x = 700
	_overlay.add_child(footer)


func _confirm_new() -> void:
	if not CaseState.has_save():
		new_case_requested.emit()
		return
	_new_overlay("confirm")
	var column := _window("Nueva investigación", "El nuevo caso reemplazará el progreso guardado.")
	column.add_child(_text("¿Reiniciar el Caso 001 desde el centro de operaciones?", 24))
	column.add_child(_button("Reiniciar el caso", func() -> void: new_case_requested.emit()))
	column.add_child(_button("Conservar mi progreso", show_menu))


func show_briefing() -> void:
	_new_overlay("briefing")
	var column := _window("Caso 001 · La pirámide", "OPERACIÓN / VENTANA AL REINO ANTIGUO")
	var body := _scroll(column)
	body.add_child(_text(String(CaseState.case_data["briefing"]), 23))
	var card := _card(body)
	card.add_child(_text("PROTOCOLO DE CAMPO", 15, GOLD))
	card.add_child(_text("Examina las tres pruebas del centro. Analízalas en el expediente y reconstruye el destino. En Guiza, escucha a los testigos, contrasta sus relatos y conserva las pruebas físicas.", 19))
	card.add_child(_text("No hay un marcador que revele al culpable. Una detención exige identidad, ubicación y motivo respaldados por pruebas. Tu equipo permite una captura no letal.", 19, MUTED))
	var controls := _card(body)
	controls.add_child(_text("WASD · moverte   /   ratón · mirar   /   E · interactuar\nTab · expediente   /   Q · escáner de proximidad   /   Esc · pausa", 18, CYAN))
	body.add_child(_button("Aceptar misión", close_overlay))


func show_pause() -> void:
	_new_overlay("pause")
	var column := _window("Investigación en pausa", "El tiempo de la misión se detiene mientras consultas interfaces.")
	column.add_child(_text(CaseState.objective(), 23))
	column.add_child(_button("Reanudar", close_overlay))
	column.add_child(_button("Guardar partida", func() -> void: save_requested.emit()))
	column.add_child(_button("Abrir expediente", show_journal))
	column.add_child(_button("Ajustes", func() -> void: show_settings("pause")))
	column.add_child(_button("Controles", func() -> void: show_controls("pause")))
	column.add_child(_button("Volver al menú", func() -> void: menu_requested.emit()))


func show_journal(page: String = "") -> void:
	if not page.is_empty():
		current_page = page
	_new_overlay("journal")
	var column := _window("Expediente temporal / 001", "Las barras expresan respaldo de las pruebas, no una probabilidad científica.")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 210
	row.add_child(navigation)
	for section: String in ["Evidencias", "Deducciones", "Sospechosos", "Mapa", "Archivo", "Cronología"]:
		var button := _button(section, func() -> void: show_journal(section))
		if section == current_page:
			button.add_theme_color_override("font_color", GOLD)
		navigation.add_child(button)
	navigation.add_child(_text("%s / %s pruebas\n%s conclusiones\nLínea %s" % [
		CaseState.collected.size(), CaseState.evidence_index.size(), CaseState.solved.size(),
		"Beta" if CaseState.alternate_line else "Alpha"
	], 15, MUTED))
	_page_content = _scroll(row)
	_render_journal_page()


func _render_journal_page() -> void:
	_clear(_page_content)
	match current_page:
		"Evidencias": _evidence_page()
		"Deducciones": _deduction_page()
		"Sospechosos": _suspect_page()
		"Mapa": _map_page()
		"Archivo": _archive_page()
		"Cronología": _timeline_page()


func _evidence_page() -> void:
	_page_content.add_child(_text("Cadena de custodia", 28, TEXT, true))
	_page_content.add_child(_text("Recoger no equivale a comprender. Analiza las muestras y separa hechos, hipótesis y rumores.", 17, MUTED))
	if CaseState.collected.is_empty():
		_page_content.add_child(_text("Todavía no hay evidencias. Comienza por el laboratorio, el archivo y las comunicaciones.", 20))
	for id: String in CaseState.collected:
		var entry := CaseState.evidence(id)
		var card := _card(_page_content)
		card.add_child(_text(String(entry["title"]), 23))
		var reliability := String(entry["reliability"])
		if id == "boatman" and CaseState.rumor_resolved:
			reliability = "Rumor descartado"
		card.add_child(_text("%s  /  %s  /  %s" % [entry["category"], reliability, "Analizada" if CaseState.analyzed.has(id) else "Análisis pendiente"], 14, GOLD))
		card.add_child(_text(String(entry["description"]), 17))
		if CaseState.analyzed.has(id):
			card.add_child(_text(String(entry["analysis"]), 17, CYAN))
		else:
			card.add_child(_button("Analizar evidencia", func() -> void: _result(CaseState.analyze_evidence(id))))


func _deduction_page() -> void:
	_page_content.add_child(_text("Reconstrucción causal", 28, TEXT, true))
	_page_content.add_child(_text("Cada conclusión requiere fuentes concretas. Una respuesta sin respaldo no autoriza el siguiente paso.", 17, MUTED))
	for entry: Dictionary in CaseState.case_data["deductions"]:
		var id := String(entry["id"])
		if id != "destination" and CaseState.zone == "hub" and CaseState.phase not in ["debrief", "complete"]:
			continue
		var card := _card(_page_content)
		card.add_child(_text(String(entry["title"]), 23))
		if CaseState.solved.has(id):
			card.add_child(_text("CONCLUSIÓN CONFIRMADA", 13, GOLD))
			card.add_child(_text(String(entry["explanation"]), 18, CYAN))
			continue
		for required: String in entry["requires"]:
			var ready := CaseState.is_evidence_ready(required)
			var title := String(CaseState.evidence(required)["title"]) if CaseState.collected.has(required) else "Prueba pendiente de recuperar"
			card.add_child(_text(("✓ " if ready else "— ") + title, 15, CYAN if ready else MUTED))
		for option: Dictionary in entry["options"]:
			var option_id := String(option["id"])
			card.add_child(_button(String(option["text"]), func() -> void: _result(CaseState.solve_deduction(id, option_id)), not CaseState.deduction_available(id)))


func _suspect_page() -> void:
	_page_content.add_child(_text("Identificación y orden de captura", 28, TEXT, true))
	_page_content.add_child(_text("Contrasta la descripción física, la firma de fabricación, la ruta y la motivación. Un rumor no añade respaldo.", 17, MUTED))
	for entry: Dictionary in CaseState.case_data["suspects"]:
		var id := String(entry["id"])
		var card := _card(_page_content)
		card.add_child(_text(String(entry["name"]), 24, GOLD if id == CaseState.selected_suspect else TEXT))
		card.add_child(_text(String(entry["occupation"]), 15, MUTED))
		card.add_child(_text(String(entry["description"]), 17))
		var support: Dictionary = CaseState.scores(id)
		var row := HBoxContainer.new()
		card.add_child(row)
		for category: String in ["identity", "location", "motive"]:
			var column := VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(column)
			var names := {"identity": "Identidad", "location": "Ubicación", "motive": "Motivo"}
			column.add_child(_text("%s · %s %%" % [names[category], support[category]], 15, CYAN))
			var bar := ProgressBar.new()
			bar.value = support[category]
			bar.show_percentage = false
			bar.custom_minimum_size.y = 5
			column.add_child(bar)
		card.add_child(_button("Hipótesis seleccionada" if id == CaseState.selected_suspect else "Seleccionar esta hipótesis", func() -> void: _result(CaseState.select_suspect(id)), not CaseState.warrant_suspect.is_empty()))
	var authorization := _card(_page_content)
	if not CaseState.warrant_suspect.is_empty():
		authorization.add_child(_text("ORDEN TEMPORAL AUTORIZADA / MARCUS VALE", 18, GOLD))
		authorization.add_child(_text("Captura no letal. Localízalo en el almacén oriental; sigue su retirada si intenta huir.", 17))
	else:
		var thresholds: Dictionary = CaseState.case_data["warrant_thresholds"]
		authorization.add_child(_text("UMBRAL / identidad %s · ubicación %s · motivo %s" % [thresholds["identity"], thresholds["location"], thresholds["motive"]], 15, GOLD))
		authorization.add_child(_text("También debes confirmar el testimonio, el sabotaje y la ruta en Deducciones.", 17, MUTED))
		authorization.add_child(_button("Solicitar orden de captura", func() -> void: _result(CaseState.request_warrant()), CaseState.selected_suspect.is_empty()))


func _map_page() -> void:
	_page_content.add_child(_text("Orientación de campo", 28, TEXT, true))
	_page_content.add_child(_text("El plano muestra lugares, no evidencias ni la posición del criminal. Usa los testimonios para decidir adónde ir.", 17, MUTED))
	if not is_instance_valid(world) or world.zone != "egypt":
		_page_content.add_child(_text("El plano de campo estará disponible al establecer la ventana temporal.", 20))
		return
	var map := TemporalMap.new()
	map.world = world
	map.player = player
	_page_content.add_child(map)
	_page_content.add_child(_text("Azul: tu posición y orientación. Ocre: edificios y áreas de trabajo. El canal queda al este.", 15, CYAN))


func _archive_page() -> void:
	_page_content.add_child(_text("Archivo histórico", 28, TEXT, true))
	_page_content.add_child(_text("Contexto documentado y límites de la reconstrucción.", 17, MUTED))
	for article: Dictionary in CaseState.case_data["archive"]:
		var id := String(article["id"])
		var card := _card(_page_content)
		card.add_child(_text(String(article["title"]), 23))
		card.add_child(_text(String(article["text"]), 18))
		card.add_child(_button("Lectura registrada" if CaseState.read_articles.has(id) else "Registrar lectura", func() -> void: CaseState.read_article(id), CaseState.read_articles.has(id)))
		if not String(article["source"]).is_empty():
			var link := LinkButton.new()
			link.text = "Referencia documental"
			link.pressed.connect(func() -> void: OS.shell_open(String(article["source"])))
			card.add_child(link)


func _timeline_page() -> void:
	_page_content.add_child(_text("Auditoría de la línea temporal", 28, TEXT, true))
	var card := _card(_page_content)
	card.add_child(_text("LÍNEA %s / divergencia %.1f %%" % ["BETA" if CaseState.alternate_line else "ALPHA", CaseState.divergence], 22, GOLD))
	card.add_child(_text("Pico registrado: %.1f %% · Tiempo de campo: %s\nLa divergencia aumenta mientras el resonador sigue activo. Las conclusiones erróneas y las persecuciones fallidas también dejan huella." % [CaseState.peak_divergence, _time(CaseState.field_seconds)], 18))
	card.add_child(_text("Resonador: %s\nResponsable: %s\nAncla: %s" % [
		"desconectado" if CaseState.neutralized else "sin neutralizar",
		"bajo custodia" if CaseState.captured else "sin capturar",
		"estabilizada" if CaseState.repaired else "pendiente"
	], 18, CYAN))
	for id: String in CaseState.solved:
		_page_content.add_child(_text("→ " + String(CaseState.deduction_index[id]["title"]), 18))
	if CaseState.rumor_resolved:
		_page_content.add_child(_text("→ Rumor del embarcadero descartado por contraste documental.", 18, MUTED))


func show_evidence(id: String) -> void:
	_new_overlay("evidence")
	var entry := CaseState.evidence(id)
	var column := _window(String(entry["title"]), "%s / %s" % [entry["category"], entry["reliability"]])
	var body := _scroll(column)
	body.add_child(_text(String(entry["description"]), 24))
	if CaseState.analyzed.has(id):
		body.add_child(_text(String(entry["analysis"]), 21, CYAN))
	else:
		body.add_child(_button("Analizar con el equipo forense", func() -> void:
			_result(CaseState.analyze_evidence(id))
			show_evidence(id)
		))
	body.add_child(_button("Abrir cadena de custodia", func() -> void: show_journal("Evidencias")))
	body.add_child(_button("Volver a la investigación", close_overlay))


func show_dialogue(id: String) -> void:
	_new_overlay("dialogue", false)
	_dialog_id = id
	var definition: Dictionary = CaseState.case_data["dialogues"][id]
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 150
	panel.offset_right = -150
	panel.offset_top = -385
	panel.offset_bottom = -30
	_overlay.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(_text("%s / %s" % [definition["name"], definition["role"]], 25, GOLD))
	column.add_child(_text("TRADUCCIÓN DEL DISPOSITIVO / TESTIMONIO", 12, MUTED))
	_dialog_response = _text(String(definition["greeting"]), 18)
	_dialog_response.custom_minimum_size.y = 60
	column.add_child(_dialog_response)
	_dialog_topics = VBoxContainer.new()
	_dialog_topics.add_theme_constant_override("separation", 5)
	column.add_child(_dialog_topics)
	_render_topics()
	var close := _button("Terminar conversación [Esc]", close_overlay)
	close.custom_minimum_size.y = 36
	close.add_theme_font_size_override("font_size", 15)
	column.add_child(close)


func _render_topics() -> void:
	_clear(_dialog_topics)
	for topic: Dictionary in CaseState.case_data["dialogues"][_dialog_id]["topics"]:
		var id := String(topic["id"])
		var disabled := int(CaseState.rapport.get(_dialog_id, 0)) < int(topic.get("requires_rapport", 0))
		var question := String(topic["question"])
		if CaseState.dialogue_seen.has(_dialog_id + ":" + id):
			question += "  [consultado]"
		var button := _button(question, func() -> void:
			var result: Dictionary = CaseState.talk(_dialog_id, id)
			if bool(result["ok"]):
				_dialog_response.text = String(result["message"])
				_render_topics()
		, disabled)
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 15)
		_dialog_topics.add_child(button)


func show_settings(origin: String) -> void:
	_settings_origin = origin
	_new_overlay("settings")
	var column := _window("Ajustes", "Movimiento de cámara, entrada, presentación y sonido.")
	var body := _scroll(column)
	_slider(body, "Sensibilidad del ratón", Preferences.sensitivity, 0.0005, 0.006, 0.0001, func(value: float) -> void: Preferences.sensitivity = value)
	_slider(body, "Campo de visión", Preferences.field_of_view, 60, 100, 1, func(value: float) -> void: Preferences.field_of_view = value)
	_slider(body, "Balanceo de cámara (0 = desactivado)", Preferences.camera_motion, 0, 1, 0.05, func(value: float) -> void: Preferences.camera_motion = value)
	_slider(body, "Volumen general", Preferences.master_volume, 0, 1, 0.05, func(value: float) -> void: Preferences.master_volume = value)
	_slider(body, "Ambiente", Preferences.ambience_volume, 0, 1, 0.05, func(value: float) -> void: Preferences.ambience_volume = value)
	_slider(body, "Efectos e interfaz", Preferences.effects_volume, 0, 1, 0.05, func(value: float) -> void: Preferences.effects_volume = value)
	var invert := CheckButton.new()
	invert.text = "Invertir eje vertical del ratón"
	invert.button_pressed = Preferences.invert_mouse
	invert.toggled.connect(func(value: bool) -> void: Preferences.invert_mouse = value)
	body.add_child(invert)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Pantalla completa"
	fullscreen.button_pressed = Preferences.fullscreen
	fullscreen.toggled.connect(func(value: bool) -> void: Preferences.fullscreen = value)
	body.add_child(fullscreen)
	var quality := OptionButton.new()
	for value: String in ["Rendimiento / sin sombras dinámicas", "Equilibrado / sombras y oclusión ambiental", "Alta / reflejos y niebla volumétrica"]:
		quality.add_item(value)
	quality.selected = Preferences.quality
	quality.item_selected.connect(func(value: int) -> void: Preferences.quality = value)
	body.add_child(quality)
	body.add_child(_button("Aplicar y guardar ajustes", func() -> void:
		Preferences.apply()
		if Preferences.persist():
			close_overlay()
	))


func _slider(parent: Node, title: String, value: float, minimum: float, maximum: float, step: float, action: Callable) -> void:
	var column := _card(parent, 12)
	var label := _text("%s / %s" % [title, "%.4f" % value if maximum < 0.1 else "%.2f" % value], 16)
	column.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(current: float) -> void:
		label.text = "%s / %s" % [title, "%.4f" % current if maximum < 0.1 else "%.2f" % current]
		action.call(current)
	)
	column.add_child(slider)


func show_controls(origin: String) -> void:
	_settings_origin = origin
	_new_overlay("controls")
	var column := _window("Controles de campo", "Teclado y ratón / primera persona")
	var body := _scroll(column)
	for line: String in [
		"WASD o flechas    /    desplazamiento",
		"Ratón    /    mirar",
		"E    /    examinar, conversar y usar dispositivos",
		"E mantenida, cerca del fugitivo    /    captura no letal con orden autorizada",
		"Mayús    /    correr; consume resistencia",
		"Ctrl    /    agacharte; no puedes levantarte bajo un obstáculo",
		"Espacio    /    saltar",
		"Tab o J    /    expediente, deducciones, sospechosos y mapa",
		"Q    /    escáner de proximidad; no atraviesa paredes",
		"F    /    linterna del equipo",
		"F5    /    guardar partida",
		"Esc    /    cerrar una interfaz o pausar"
	]:
		body.add_child(_text(line, 19))
	body.add_child(_text("El juego no requiere violencia letal. Las interfaces pausan la simulación y el reloj de divergencia. Puedes desactivar el balanceo de cámara en Ajustes.", 18, CYAN))


func show_credits(origin: String) -> void:
	_settings_origin = origin
	_new_overlay("credits")
	var column := _window("Recursos y documentación", "Procedencia y licencias verificables")
	var body := _scroll(column)
	body.add_child(_text("Modelos escaneados y materiales PBR: Poly Haven / CC0.\nAnatomía, pesos esqueléticos, ojos y piel: MakeHuman Community / CC0.\nVestimenta, animaciones, arquitectura, interfaz, efectos y audio procedural: creados para este proyecto.\nFuentes Manrope y Cinzel: SIL Open Font License.", 22))
	body.add_child(_text("El manifiesto assets/manifest.json conserva URL, tamaño y SHA256 de cada descarga. Los textos de licencia están en assets/licenses. El juego funciona sin conexión y no transmite datos.", 19, MUTED))
	body.add_child(_text("Referencias históricas: Giza Project (Harvard), Ancient Egypt Research Associates y el estudio del antiguo brazo del Nilo publicado en Communications Earth & Environment. El escenario es una interpretación artística, no una reconstrucción arqueológica certificada.", 19))
	body.add_child(_text("Esta entrega comprende un caso completo. No incluye una campaña de otras épocas, voces interpretadas ni captura de movimiento.", 18, CYAN))


func show_loading(destination: String) -> void:
	_new_overlay("loading")
	_shade.color = Color(0.015, 0.032, 0.043, 1)
	var column := VBoxContainer.new()
	column.position = Vector2(420, 320)
	column.size = Vector2(760, 220)
	_overlay.add_child(column)
	column.add_child(_text("MERIDIAN", 58, GOLD, true))
	column.add_child(_text("ESTABLECIENDO VENTANA TEMPORAL", 15, MUTED))
	column.add_child(_text(destination, 27))


func finish_loading() -> void:
	overlay_kind = "loaded"
	close_overlay()


func show_report() -> void:
	_new_overlay("report")
	var report: Dictionary = CaseState.report()
	var column := _window("Caso 001 / expediente cerrado", "Comparación entre registro original y presente observado")
	var body := _scroll(column)
	body.add_child(_text("EVALUACIÓN %s  /  %s" % [report["grade"], report["line"]], 36, GOLD, true))
	body.add_child(_text(String(report["summary"]), 23))
	body.add_child(_text("Pruebas: %s de %s\nTiempo de campo: %s\nDivergencia máxima: %.1f %%\nConclusiones erróneas: %s\nIntentos de captura: %s" % [
		report["clues"], report["total_clues"], _time(report["seconds"]),
		report["peak"], report["mistakes"], report["attempts"]
	], 19, CYAN))
	var epilogue := _card(body)
	epilogue.add_child(_text("ARCHIVO ASTERIÓN / ACCESO RESTRINGIDO", 14, GOLD))
	epilogue.add_child(_text(String(report["epilogue"]), 22))
	body.add_child(_text("Fin del Caso 001. Las otras épocas quedan fuera de esta entrega.", 16, MUTED))
	body.add_child(_button("Volver al menú", func() -> void: menu_requested.emit()))


func _result(result: Dictionary) -> void:
	if bool(result["ok"]):
		toast(String(result["message"]))
		Soundscape.play_ui("evidence")


func _on_case_changed() -> void:
	if overlay_kind == "journal" and not _refresh_pending:
		_refresh_pending = true
		call_deferred("_refresh_journal")


func _refresh_journal() -> void:
	_refresh_pending = false
	if overlay_kind == "journal" and is_instance_valid(_page_content):
		_render_journal_page()


func _time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
