extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/linen/textures/rough_linen_diff_2k.jpg"))
	if source == null:
		push_error("Falta la textura original CC0 de lino.")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var pixels := source.get_data()
	for index: int in range(0, pixels.size(), 4):
		var luminance := pixels[index] * 0.2126 + pixels[index + 1] * 0.7152 + pixels[index + 2] * 0.0722
		var neutral := clampi(int(182.0 + (luminance - 164.0) * 0.85), 60, 230)
		pixels[index] = neutral
		pixels[index + 1] = clampi(int(neutral * 0.975), 0, 255)
		pixels[index + 2] = clampi(int(neutral * 0.91), 0, 255)
	var undyed := Image.create_from_data(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8, pixels)
	var error := undyed.save_png("res://assets/textures/linen/linen_undyed.png")
	if error != OK:
		push_error("No se pudo generar el lino sin teñir: %s." % error_string(error))
		quit(1)
		return
	print("CC0 derivative: linen_undyed.png (%s x %s)." % [undyed.get_width(), undyed.get_height()])
	quit()
