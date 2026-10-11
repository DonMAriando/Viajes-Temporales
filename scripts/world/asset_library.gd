class_name AssetLibrary
extends RefCounted

static var _manifest: Dictionary = {}
static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}


static func _ensure_manifest() -> void:
	if not _manifest.is_empty():
		return
	var file := FileAccess.open("res://assets/manifest.json", FileAccess.READ)
	assert(file != null, "Faltan los recursos: ejecuta node tools\\fetch_assets.mjs.")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "El manifiesto de recursos no es válido.")
	for entry: Dictionary in parsed["assets"]:
		if entry.has("name"):
			_manifest[String(entry["name"])] = entry


static func pbr(name: String, tile_meters: float = 2.0) -> StandardMaterial3D:
	_ensure_manifest()
	var cache_key := "%s:%.2f" % [name, tile_meters]
	if _materials.has(cache_key):
		return _materials[cache_key]
	assert(_manifest.has(name), "Material desconocido: %s." % name)
	var entry: Dictionary = _manifest[name]
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.roughness = 0.92
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / tile_meters
	material.uv1_triplanar_sharpness = 8.0
	for item: Dictionary in entry["files"]:
		var path := String(item["path"])
		if "_diff_" in path:
			material.albedo_texture = load("res://" + path)
		elif "_nor_gl_" in path:
			material.normal_enabled = true
			material.normal_texture = load("res://" + path)
			material.normal_scale = 0.8
		elif "_rough_" in path:
			material.roughness_texture = load("res://" + path)
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		elif "_arm_" in path:
			var packed: Texture2D = load("res://" + path)
			material.ao_enabled = true
			material.ao_texture = packed
			material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.roughness_texture = packed
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			if name == "metal":
				material.metallic_texture = packed
				material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	assert(material.albedo_texture != null, "Falta el albedo del material %s." % name)
	if name == "linen":
		material.albedo_texture = load("res://assets/textures/linen/linen_undyed.png")
		assert(material.albedo_texture != null, "Falta el lino sin teñir: ejecuta tools\\prepare_textures.gd.")
	if name == "metal":
		material.metallic = 0.8
		material.roughness = 0.65
	_materials[cache_key] = material
	return material


static func solid(color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func emissive(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var material := solid(color, 0.4)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func model(name: String) -> Node3D:
	_ensure_manifest()
	assert(_manifest.has(name), "Modelo desconocido: %s." % name)
	if not _scenes.has(name):
		_scenes[name] = load("res://" + String(_manifest[name]["scene"]))
	var scene: PackedScene = _scenes[name]
	assert(scene != null, "No se pudo importar el modelo %s." % name)
	return scene.instantiate()


static func character(traveler: bool = false) -> Node3D:
	var id := "traveler" if traveler else "egyptian"
	if not _scenes.has(id):
		_scenes[id] = load("res://assets/models/characters/%s.glb" % id)
	var scene: PackedScene = _scenes[id]
	assert(scene != null, "Faltan los personajes: ejecuta node tools\\build_characters.mjs.")
	return scene.instantiate()


static func bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var initialized := false
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			result = transform * mesh_node.get_aabb()
			initialized = true
	for child: Node in node.get_children():
		if child is Node3D:
			var child_bounds := bounds(child, transform * (child as Node3D).transform)
			if child_bounds.size.length_squared() > 0.0:
				result = result.merge(child_bounds) if initialized else child_bounds
				initialized = true
	return result


static func release_cached_resources() -> void:
	_materials.clear()
	_scenes.clear()
	_manifest.clear()
