extends Node

signal updated
signal storage_error(message: String)

const PATH := "user://preferences.cfg"

var sensitivity: float = 0.0022
var invert_mouse: bool = false
var field_of_view: float = 78.0
var camera_motion: float = 0.35
var master_volume: float = 0.8
var ambience_volume: float = 0.65
var effects_volume: float = 0.8
var fullscreen: bool = false
var quality: int = 1


func _ready() -> void:
	var config := ConfigFile.new()
	var error := config.load(PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		_report_error("No se pudieron leer los ajustes: %s." % error_string(error))
		return
	sensitivity = clampf(float(config.get_value("input", "sensitivity", sensitivity)), 0.0005, 0.006)
	invert_mouse = bool(config.get_value("input", "invert_mouse", invert_mouse))
	field_of_view = clampf(float(config.get_value("camera", "fov", field_of_view)), 60.0, 100.0)
	camera_motion = clampf(float(config.get_value("camera", "motion", camera_motion)), 0.0, 1.0)
	master_volume = clampf(float(config.get_value("audio", "master", master_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(config.get_value("audio", "ambience", ambience_volume)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("audio", "effects", effects_volume)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	quality = clampi(int(config.get_value("display", "quality", quality)), 0, 2)


func apply() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	updated.emit()


func persist() -> bool:
	var config := ConfigFile.new()
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("input", "invert_mouse", invert_mouse)
	config.set_value("camera", "fov", field_of_view)
	config.set_value("camera", "motion", camera_motion)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "ambience", ambience_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "quality", quality)
	var error := config.save(PATH)
	if error != OK:
		_report_error("No se pudieron guardar los ajustes: %s." % error_string(error))
		return false
	return true


func _report_error(message: String) -> void:
	push_error(message)
	storage_error.emit(message)
