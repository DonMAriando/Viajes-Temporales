class_name TemporalMap
extends Control

var world: TemporalWorld
var player: FirstPersonAgent
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(640, 430)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font = load("res://assets/fonts/manrope.ttf")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(world) or world.zone != "egypt":
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.065, 0.095, 0.105))
	var bounds := Rect2(Vector2(-66, -42), Vector2(144, 124))
	var scale_factor := minf((size.x - 70) / bounds.size.x, (size.y - 60) / bounds.size.y)
	var origin := (size - bounds.size * scale_factor) * 0.5
	for i: int in range(15):
		var x := origin.x + i * 10 * scale_factor
		draw_line(Vector2(x, origin.y), Vector2(x, origin.y + bounds.size.y * scale_factor), Color(0.12, 0.16, 0.16))
	for i: int in range(13):
		var y := origin.y + i * 10 * scale_factor
		draw_line(Vector2(origin.x, y), Vector2(origin.x + bounds.size.x * scale_factor, y), Color(0.12, 0.16, 0.16))
	draw_rect(Rect2(origin + Vector2(140, 0) * scale_factor, Vector2(4, 124) * scale_factor), Color(0.18, 0.32, 0.33))
	for obstacle: Rect2 in world.map_obstacles():
		draw_rect(Rect2(origin + (obstacle.position - bounds.position) * scale_factor, obstacle.size * scale_factor), Color(0.38, 0.34, 0.26))
	for landmark: Dictionary in world.landmarks:
		var point: Vector3 = landmark["position"]
		var screen := origin + (Vector2(point.x, point.z) - bounds.position) * scale_factor
		draw_circle(screen, 3.5, Color(0.82, 0.71, 0.48))
		var text := String(landmark["name"])
		var text_width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var label_position := screen + Vector2(8, -6)
		label_position.x = minf(label_position.x, size.x - text_width - 8)
		draw_string(_font, label_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.83, 0.81, 0.72))
	if is_instance_valid(player):
		var point := origin + (Vector2(player.global_position.x, player.global_position.z) - bounds.position) * scale_factor
		draw_circle(point, 5, Color(0.56, 0.86, 0.87))
		var direction := Vector2(-sin(player.rotation.y), -cos(player.rotation.y))
		draw_line(point, point + direction * 16, Color(0.65, 0.93, 0.93), 2.0)
	draw_string(_font, Vector2(18, 25), "N ↑   /   Plano orientativo, no arqueológico", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.68, 0.74, 0.71))
