class_name TemporalWorld
extends Node3D

var zone: String = "hub"
var spawn_point := Vector3(0.0, 0.1, 8.0)
var spawn_yaw: float = 0.0
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var suspect: TemporalNPC
var landmarks: Array[Dictionary] = []
var _obstacles: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()
var _anchor_light: OmniLight3D
var _field_materials: Array[ShaderMaterial] = []
var _resonator_lens: MeshInstance3D


func build(destination: String) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	zone = destination
	name = "Guiza" if zone == "egypt" else "OperationsCenter"
	_rng.seed = 2560001
	_environment()
	if zone == "egypt":
		_build_egypt()
	else:
		_build_hub()
	apply_quality()
	sync_case_state()


func _environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	if zone == "egypt":
		sky_material.sky_top_color = Color(0.22, 0.39, 0.56)
		sky_material.sky_horizon_color = Color(0.78, 0.76, 0.64)
		sky_material.ground_bottom_color = Color(0.32, 0.28, 0.21)
		sky_material.ground_horizon_color = Color(0.72, 0.66, 0.49)
		environment.ambient_light_energy = 0.65
		environment.tonemap_exposure = 0.95
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.73, 0.67, 0.52)
		environment.fog_density = 0.0014
		environment.fog_sky_affect = 0.25
	else:
		sky_material.sky_top_color = Color(0.025, 0.046, 0.085)
		sky_material.sky_horizon_color = Color(0.12, 0.17, 0.23)
		sky_material.ground_bottom_color = Color(0.025, 0.033, 0.044)
		sky_material.ground_horizon_color = Color(0.12, 0.14, 0.16)
		environment.ambient_light_energy = 0.3
		environment.tonemap_exposure = 1.2
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.08
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.1
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, -38.0, 0.0) if zone == "egypt" else Vector3(-28.0, -45.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.72) if zone == "egypt" else Color(0.55, 0.68, 0.88)
	sun.light_energy = 2.0 if zone == "egypt" else 0.22
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0 if zone == "egypt" else 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.3
	add_child(sun)


func apply_quality() -> void:
	var environment := world_environment.environment
	environment.ssao_enabled = Preferences.quality > 0
	environment.glow_enabled = Preferences.quality > 0
	environment.ssr_enabled = Preferences.quality == 2 or (Preferences.quality == 1 and zone == "hub")
	environment.volumetric_fog_enabled = Preferences.quality == 2 and zone == "egypt"
	environment.volumetric_fog_density = 0.003
	environment.volumetric_fog_albedo = Color(0.8, 0.74, 0.59)
	sun.shadow_enabled = Preferences.quality > 0


func _build_hub() -> void:
	var metal := AssetLibrary.pbr("metal", 2.5)
	var dark := AssetLibrary.solid(Color(0.065, 0.085, 0.095), 0.55, 0.55)
	var wall := AssetLibrary.solid(Color(0.16, 0.19, 0.205), 0.8, 0.15)
	var warm := AssetLibrary.emissive(Color(0.93, 0.75, 0.43), 1.8)
	var cool := AssetLibrary.emissive(Color(0.38, 0.65, 0.7), 1.2)
	_box(Vector3(0, -0.16, -3), Vector3(25, 0.3, 30), metal, true, "stone")
	_box(Vector3(-12.5, 2.3, -3), Vector3(0.4, 4.6, 30), wall)
	_box(Vector3(12.5, 2.3, -3), Vector3(0.4, 4.6, 30), wall)
	for x: float in [-7.0, 7.0]:
		_box(Vector3(x, 2.3, 12), Vector3(11, 4.6, 0.4), wall)
	_box(Vector3(0, 3.85, 12), Vector3(3, 1.5, 0.4), wall)
	_hub_entrance(metal, dark, warm)
	_box(Vector3(0, 2.3, -18), Vector3(25, 4.6, 0.4), wall)
	_box(Vector3(0, 4.65, -3), Vector3(25, 0.12, 30), dark)
	for x: float in [-10.0, -6.0, 0.0, 6.0, 10.0]:
		_box(Vector3(x, 4.5, -3), Vector3(0.18, 0.12, 28), dark, false)
		_box(Vector3(x, 4.42, -3), Vector3(0.06, 0.015, 24), warm if absf(x) > 8 else cool, false)
	for z: float in [-14.0, -5.0, 6.0]:
		_light(Vector3(-6, 3.7, z), Color(0.95, 0.83, 0.65), 4.0, 11.0, z == -5.0)
		_light(Vector3(6, 3.7, z), Color(0.6, 0.79, 0.88), 3.4, 11.0)
	for x: float in [-11.9, 11.9]:
		for z: float in [-14.0, -8.0, -2.0, 4.0, 10.0]:
			_box(Vector3(x, 1.55, z), Vector3(0.25, 3.1, 0.7), dark)
			_box(Vector3(x * 0.991, 1.55, z), Vector3(0.04, 2.1, 0.025), cool, false)
	_box(Vector3(-8, 0.8, -4), Vector3(4.2, 0.12, 1.8), metal)
	_box(Vector3(-8, 0.35, -4), Vector3(3.8, 0.7, 1.45), dark)
	_box(Vector3(-8, 1.04, -4), Vector3(1.1, 0.06, 0.65), dark)
	_box(Vector3(-8, 1.12, -4), Vector3(0.32, 0.045, 0.14), metal, false).rotation_degrees.y = -19
	_interaction("alloy", "evidence", "Fragmento de aleación", Vector3(-8, 1.15, -3.7))
	_label("LABORATORIO FORENSE", Vector3(-8, 2.4, -4.8), 0.004, Color(0.73, 0.82, 0.82))
	_terminal(Vector3(7, 0, -4), "ARCHIVO HISTÓRICO\nRegistro temporal · 001", cool)
	_interaction("travel_log", "evidence", "Registro temporal dañado", Vector3(7, 1.18, -3.5))
	_terminal(Vector3(-7, 0, -12), "COMUNICACIONES\nEnlace interceptado · Asterión", warm)
	_interaction("intercept", "evidence", "Comunicación interceptada", Vector3(-7, 1.18, -11.5))
	_terminal(Vector3(0, 0, 0), "MERIDIAN\nDIVISIÓN DE DELITOS TEMPORALES", cool)
	_interaction("case_console", "console", "Consola del caso", Vector3(0, 1.15, 0.5))
	for i: int in range(5):
		var z := -14.0 + i * 3.8
		_box(Vector3(10.8, 1.15, z), Vector3(1.2, 2.3, 2.8), dark)
		for j: int in range(4):
			_box(Vector3(10.16, 0.5 + j * 0.43, z), Vector3(0.035, 0.14, 2.1), metal, false)
			_box(Vector3(10.12, 0.52 + j * 0.43, z - 0.9), Vector3(0.025, 0.025, 0.2), cool, false)
	for i: int in range(3):
		_prop("crate", Vector3(-10.4, 0, 4.5 + i * 1.5), 0.7, 0.0, true)
	_portal(Vector3(0, 0.22, -11))
	_box(Vector3(0, 0.12, -11), Vector3(5.5, 0.25, 3.2), dark)
	_terminal(Vector3(3.8, 0, -8), "VENTANA TEMPORAL\nDestino pendiente", cool)
	_interaction("time_gate", "portal", "Dispositivo temporal", Vector3(3.8, 1.15, -7.5))
	_label("INVESTIGAR EL PASADO\nPROTEGER EL FUTURO", Vector3(0, 2.5, -17.74), 0.009, Color(0.68, 0.73, 0.74))
	_label("MERIDIAN", Vector3(0, 3.35, -17.72), 0.016, Color(0.83, 0.7, 0.47))
	for x: float in [-4.0, 4.0]:
		_box(Vector3(x, 0.02, -5), Vector3(0.015, 0.005, 24), warm, false)
	landmarks = [
		{"name": "Sala de operaciones", "position": Vector3(0, 0, 3)},
		{"name": "Acceso principal", "position": Vector3(0, 0, 10.6)},
		{"name": "Laboratorio forense", "position": Vector3(-8, 0, -4)},
		{"name": "Archivo histórico", "position": Vector3(7, 0, -4)},
		{"name": "Cámara temporal", "position": Vector3(0, 0, -11)}
	]
	if CaseState.captured:
		_custody_room()


func _hub_entrance(metal: Material, dark: Material, locked: Material) -> void:
	var door := _box(Vector3(0, 1.45, 11.91), Vector3(2.66, 2.9, 0.22), dark)
	door.name = "AgencyEntrance"
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 1.42, 1.55, 11.92), Vector3(0.18, 3.1, 0.4), dark)
		_box(Vector3(side * 0.67, 1.45, 11.78), Vector3(1.30, 2.82, 0.035), metal, false)
		_box(Vector3(side * 0.67, 1.55, 11.755), Vector3(0.76, 1.85, 0.02), dark, false)
		_box(Vector3(side * 0.23, 1.15, 11.72), Vector3(0.045, 0.5, 0.045), metal, false)
		_box(Vector3(side * 1.31, 1.5, 11.71), Vector3(0.024, 2.6, 0.025), locked, false)
	_box(Vector3(0, 3.0, 11.92), Vector3(3.02, 0.2, 0.4), dark)
	_box(Vector3(0, 3.0, 11.71), Vector3(2.55, 0.025, 0.025), locked, false)
	_box(Vector3(0, 0.014, 11.55), Vector3(2.8, 0.028, 0.65), metal, false)
	_box(Vector3(1.95, 1.3, 11.72), Vector3(0.24, 0.4, 0.14), dark)
	_box(Vector3(1.95, 1.35, 11.64), Vector3(0.07, 0.09, 0.02), locked, false)
	_label("ACCESO PRINCIPAL", Vector3(0, 3.52, 11.7), 0.004, Color(0.83, 0.78, 0.66)).rotation.y = PI
	_label("CERRADO / CONTROL DE SEGURIDAD", Vector3(0, 3.25, 11.7), 0.0018, Color(0.83, 0.7, 0.47)).rotation.y = PI
	_light(Vector3(0, 2.7, 10.6), Color(0.95, 0.83, 0.65), 2.6, 5.0)


func _build_egypt() -> void:
	spawn_point = Vector3(0, 0.15, 46.5)
	_ground()
	_pyramid(Vector3(0, 0, -156))
	_house(Vector3(-26, 0, 21), 11.0, 9.0, 3.0)
	_house(Vector3(-32, 0, -3), 10.0, 9.0, 3.1)
	_house(Vector3(43, 0, -20), 12.0, 11.0, 3.7)
	_house(Vector3(-48, 0, 12), 10.0, 12.0, 3.0)
	_house(Vector3(-48, 0, -15), 11.0, 13.0, 3.2)
	_house(Vector3(43, 0, 24), 10.0, 11.0, 2.9)
	_house(Vector3(20, 0, 52), 11.0, 9.0, 2.9)
	_house(Vector3(-25, 0, 55), 10.0, 11.0, 2.7)
	_awning(Vector3(-25, 2.85, 31), Vector2(10, 7))
	_awning(Vector3(-31, 2.6, 7), Vector2(8, 6))
	_light(Vector3(-23, 2.4, 31), Color(1.0, 0.86, 0.67), 2.0, 8.0)
	_light(Vector3(-30, 2.3, 8), Color(1.0, 0.86, 0.67), 1.5, 7.0)
	_table(Vector3(-25, 0, 30), Vector2(3.2, 1.2))
	_table(Vector3(-31, 0, 7), Vector2(2.8, 1.1))
	_prop("pottery", Vector3(-25.8, 0.86, 30), 0.48, 0.3)
	_prop("vase", Vector3(-24.5, 0.86, 30), 0.4, -0.2)
	_prop("basket", Vector3(-24, 0, 31.8), 0.62, 0.1, true)
	_prop("basket_round", Vector3(-26.5, 0, 31.5), 0.52, -0.3, true)
	_box(Vector3(-24.0, 0.885, 30.1), Vector3(0.19, 0.018, 0.09), AssetLibrary.pbr("metal", 1.0), false)
	_interaction("payment", "evidence", "Pago anacrónico", Vector3(-24, 0.94, 30.1))
	_papyrus(Vector3(-31, 0.86, 7))
	_wedge(Vector3(12, 0, -30), 9.0, 30.0, 9.0)
	_obstacles.append(Rect2(Vector2(6.0, -60.0), Vector2(12.0, 32.0)))
	for i: int in range(12):
		var point := Vector3(3 + (i % 4) * 2.1, 0.65 + (i / 4) * 1.2, -26 - (i % 3) * 1.7)
		_box(point, Vector3(1.85, 1.2, 1.4), AssetLibrary.pbr("limestone", 3.0))
		_obstacles.append(Rect2(Vector2(point.x - 1.25, point.z - 1.05), Vector2(2.5, 2.1)))
	_sled(Vector3(24, 0, -21))
	_sled(Vector3(31, 0, -31))
	_device(Vector3(1, 0, -27))
	_interaction("sabotage_device", "device", "Resonador de fractura", Vector3(1, 0.75, -27))
	_bootprint(Vector3(43, 0, -13))
	_interaction("route", "evidence", "Huella del almacén", Vector3(43, 0.12, -13))
	_anchor(Vector3(0, 0, 43))
	_interaction("field_anchor", "anchor", "Ancla temporal", Vector3(0, 0.85, 43))
	_npc("merchant", "Menna", Vector3(-21, 0.04, 29), -0.7)
	_npc("scribe", "Nefer", Vector3(-29, 0.04, 9), 0.1)
	_npc("builder", "Hori", Vector3(14, 0.04, -20), 2.2)
	_npc("boatman", "Seneb", Vector3(64, 0.04, 59), -1.3)
	suspect = _npc("vale", "Marcus Vale", Vector3(44, 0.04, -12), 2.3, true)
	suspect.escape_route.assign([
		Vector3(52, 0, -8), Vector3(34, 0, 6), Vector3(27, 0, 19),
		Vector3(30, 0, 34), Vector3(44, 0, 43), Vector3(55, 0, 54),
		Vector3(63, 0, 61), Vector3(69, 0.25, 61)
	])
	for i: int in range(4):
		var points: Array[Vector3] = []
		match i:
			0: points.assign([Vector3(-8, 0, 21), Vector3(-12, 0, 9), Vector3(-6, 0, -10)])
			1: points.assign([Vector3(18, 0, 7), Vector3(27, 0, 7), Vector3(28, 0, -12)])
			2: points.assign([Vector3(2, 0, 20), Vector3(12, 0, 30), Vector3(11, 0, 40)])
			3: points.assign([Vector3(53, 0, 42), Vector3(61, 0, 36), Vector3(60, 0, 18)])
		var worker := _npc("worker_%s" % i, "Trabajador de la cuadrilla", points[0] + Vector3.UP * 0.04, 0)
		worker.patrol_points = points
	_decorate_settlement()
	_canal_and_dock()
	_navigation_mesh()
	landmarks = [
		{"name": "Mercado de provisiones", "position": Vector3(-25, 0, 28)},
		{"name": "Registro de la obra", "position": Vector3(-31, 0, 7)},
		{"name": "Rampa de construcción", "position": Vector3(12, 0, -25)},
		{"name": "Almacén oriental", "position": Vector3(43, 0, -18)},
		{"name": "Embarcadero", "position": Vector3(66, 0, 59)},
		{"name": "Punto de anclaje", "position": Vector3(0, 0, 43)}
	]


func _ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 100
	var step := 6.0
	for z: int in range(cells):
		for x: int in range(cells):
			var x0 := (x - cells / 2.0) * step
			var z0 := (z - cells / 2.0) * step
			var p := [
				Vector3(x0, _height_at(x0, z0), z0),
				Vector3(x0, _height_at(x0, z0 + step), z0 + step),
				Vector3(x0 + step, _height_at(x0 + step, z0 + step), z0 + step),
				Vector3(x0 + step, _height_at(x0 + step, z0), z0)
			]
			# Godot uses clockwise front faces, including the collision mesh.
			for index: int in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(p[index])
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = surface.commit()
	terrain.material_override = AssetLibrary.pbr("sand", 6.0)
	add_child(terrain)
	terrain.create_trimesh_collision()
	var body := terrain.get_child(0) as StaticBody3D
	body.set_meta("surface", "sand")


func _height_at(x: float, z: float) -> float:
	if x > 76.0:
		return -5.0
	var edge := maxf(absf(x) - 85.0, absf(z) - 110.0)
	if edge <= 0.0:
		return 0.0
	return (sin(x * 0.018 + z * 0.013) * 0.5 + 0.5) * minf(edge * 0.25, 20.0)


func _pyramid(center: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := AssetLibrary.pbr("limestone", 5.0).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = 116
	for i: int in range(instances.instance_count):
		var height := 1.12
		var y := i * height
		var width := 230.0 * (1.0 - y / 146.6)
		var transform := Transform3D(Basis.from_scale(Vector3(width, height, width)), center + Vector3(0, y + height * 0.5, 0))
		instances.set_instance_transform(i, transform)
		var shade := _rng.randf_range(0.87, 1.0)
		instances.set_instance_color(i, Color(shade, shade * 0.98, shade * 0.94))
	var pyramid := MultiMeshInstance3D.new()
	pyramid.multimesh = instances
	add_child(pyramid)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for y: float in [0.0, 129.92]:
		var half_width := 115.0 * (1.0 - y / 146.6)
		for x: float in [-half_width, half_width]:
			for z: float in [-half_width, half_width]:
				points.append(Vector3(x, y, z))
	shape.points = points
	collider.shape = shape
	body.add_child(collider)
	body.position = center
	add_child(body)


func _house(center: Vector3, width: float, depth: float, height: float) -> void:
	var plaster := AssetLibrary.pbr("plaster", 3.0)
	_box(center + Vector3(-width * 0.5, height * 0.5, 0), Vector3(0.42, height, depth), plaster)
	_box(center + Vector3(width * 0.5, height * 0.5, 0), Vector3(0.42, height, depth), plaster)
	_box(center + Vector3(0, height * 0.5, -depth * 0.5), Vector3(width, height, 0.42), plaster)
	var side := (width - 1.6) * 0.5
	for direction: float in [-1.0, 1.0]:
		_box(center + Vector3(direction * (0.8 + side * 0.5), height * 0.5, depth * 0.5), Vector3(side, height, 0.42), plaster)
	_box(center + Vector3(0, 2.35 + (height - 2.35) * 0.5, depth * 0.5), Vector3(1.6, height - 2.35, 0.42), plaster)
	_box(center + Vector3(0, height + 0.06, 0), Vector3(width + 0.4, 0.16, depth + 0.4), plaster, true)
	var wood := AssetLibrary.pbr("wood", 1.2)
	for i: int in range(int(width)):
		_box(center + Vector3(-width * 0.5 + i + 0.5, height - 0.1, 0), Vector3(0.12, 0.16, depth + 0.65), wood, false)
	_obstacles.append(Rect2(Vector2(center.x - width * 0.5 - 0.75, center.z - depth * 0.5 - 0.75), Vector2(width + 1.5, depth + 1.5)))


func _awning(center: Vector3, size: Vector2) -> void:
	var wood := AssetLibrary.pbr("wood", 1.0)
	for x: float in [-size.x * 0.5, size.x * 0.5]:
		for z: float in [-size.y * 0.5, size.y * 0.5]:
			_cylinder(Vector3(center.x + x, center.y * 0.5, center.z + z), 0.085, center.y, wood)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution := 16
	for row: int in range(resolution):
		for col: int in range(resolution):
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
				var u := float(col + offset.x) / resolution
				var v := float(row + offset.y) / resolution
				surface.set_uv(Vector2(u, v))
				surface.add_vertex(Vector3((u - 0.5) * size.x, -sin(u * PI) * sin(v * PI) * 0.28, (v - 0.5) * size.y))
	surface.generate_normals()
	surface.generate_tangents()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/cloth.gdshader")
	material.set_shader_parameter("cloth_albedo", load("res://assets/textures/linen/linen_undyed.png"))
	material.set_shader_parameter("cloth_normal", load("res://assets/textures/linen/textures/rough_linen_nor_gl_2k.jpg"))
	var cloth := MeshInstance3D.new()
	cloth.mesh = surface.commit()
	cloth.material_override = material
	cloth.position = center
	add_child(cloth)


func _table(point: Vector3, size: Vector2) -> void:
	var wood := AssetLibrary.pbr("wood", 1.4)
	_box(point + Vector3(0, 0.82, 0), Vector3(size.x, 0.12, size.y), wood)
	for x: float in [-size.x * 0.4, size.x * 0.4]:
		for z: float in [-size.y * 0.35, size.y * 0.35]:
			_box(point + Vector3(x, 0.4, z), Vector3(0.09, 0.8, 0.09), wood)


func _papyrus(point: Vector3) -> void:
	var material := AssetLibrary.pbr("linen", 0.8).duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.89, 0.78, 0.55)
	_box(point, Vector3(0.65, 0.015, 0.4), material, false)
	for i: int in range(7):
		_box(point + Vector3(-0.2 + i * 0.067, 0.01, 0), Vector3(0.006, 0.002, 0.26), AssetLibrary.solid(Color(0.23, 0.19, 0.12)), false)


func _wedge(point: Vector3, width: float, depth: float, height: float) -> void:
	var vertices := PackedVector3Array([
		Vector3(-width / 2, 0, 0), Vector3(width / 2, 0, 0),
		Vector3(-width / 2, 0, -depth), Vector3(width / 2, 0, -depth),
		Vector3(-width / 2, height, -depth), Vector3(width / 2, height, -depth)
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in [0, 4, 5, 0, 5, 1, 0, 2, 4, 1, 5, 3, 2, 3, 5, 2, 5, 4, 0, 1, 3, 0, 3, 2]:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = AssetLibrary.pbr("limestone", 4.0)
	instance.position = point
	add_child(instance)
	instance.create_trimesh_collision()


func _sled(point: Vector3) -> void:
	var wood := AssetLibrary.pbr("wood", 1.0)
	for side: float in [-0.65, 0.65]:
		_box(point + Vector3(side, 0.13, 0), Vector3(0.16, 0.22, 3.2), wood)
	for i: int in range(7):
		_box(point + Vector3(0, 0.26, -1.2 + i * 0.4), Vector3(1.7, 0.12, 0.25), wood)
	_box(point + Vector3(0, 0.82, 0), Vector3(1.4, 1.0, 1.8), AssetLibrary.pbr("limestone", 3))
	_obstacles.append(Rect2(Vector2(point.x - 1.15, point.z - 1.85), Vector2(2.3, 3.7)))


func _decorate_settlement() -> void:
	for i: int in range(28):
		var point := Vector3(_rng.randf_range(-55, 55), 0, _rng.randf_range(-30, 65))
		if _blocked(Vector2(point.x, point.z), 2.2) or point.distance_to(spawn_point) < 7.0:
			continue
		if i % 3 == 0:
			_prop("pottery", point, _rng.randf_range(0.45, 0.75), _rng.randf_range(-PI, PI), true)
		else:
			_prop("small_rocks", point, _rng.randf_range(0.08, 0.22), _rng.randf_range(-PI, PI))
	for i: int in range(20):
		var point := Vector3(-68 + _rng.randf_range(-6, 5), 0, -33 + i * 5.5)
		_prop("rocks", point, _rng.randf_range(1.2, 2.9), _rng.randf_range(-PI, PI), true)
	for point: Vector3 in [Vector3(70, 0, 45), Vector3(70, 0, 18), Vector3(65, 0, -15), Vector3(67, 0, 73), Vector3(-57, 0, 46)]:
		_palm(point)
	for i: int in range(8):
		var point := Vector3(-40 + i * 8, 0, 70)
		_prop("basket_round", point, 0.45, i * 0.7)
		_cylinder(point + Vector3(0, 0.16, 1), 0.09, 0.3, AssetLibrary.pbr("wood", 1.0), false)


func _palm(point: Vector3) -> void:
	var bark := AssetLibrary.pbr("bark", 0.8)
	var height := _rng.randf_range(7.0, 10.0)
	for i: int in range(20):
		var y := height * (i + 0.5) / 20.0
		_cylinder(point + Vector3(sin(y * 0.15) * 0.25, y, 0), 0.16 - i * 0.002, height / 20.0, bark, false)
	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = load("res://shaders/foliage.gdshader")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf: int in range(14):
		var angle := leaf * TAU / 14.0
		var forward := Vector3(sin(angle), 0, cos(angle))
		var side := Vector3(cos(angle), 0, -sin(angle))
		for segment: int in range(32):
			var t := (segment + 1.0) / 34.0
			var stem := forward * t * 4.1 + Vector3(0, sin(t * PI) * 0.8 - t * t * 1.9, 0)
			for direction: float in [-1.0, 1.0]:
				var blade_length := sin(t * PI) * 0.75 + 0.12
				var end := stem + side * blade_length * direction + forward * 0.23 + Vector3.DOWN * 0.15
				var mid := stem.lerp(end, 0.45) + Vector3.UP * 0.045
				var width := forward * (0.03 + 0.012 * sin(t * PI))
				var vertices := [stem, mid - width, mid + width, mid - width, end, mid + width]
				var uvs := [Vector2(0.5, 0), Vector2(0, 0.45), Vector2(1, 0.45), Vector2(0, 0.45), Vector2(0.5, 1), Vector2(1, 0.45)]
				for index: int in range(6):
					surface.set_uv(uvs[index])
					surface.add_vertex(vertices[index])
	surface.generate_normals()
	var leaves := MeshInstance3D.new()
	leaves.mesh = surface.commit()
	leaves.material_override = leaf_material
	leaves.position = point + Vector3(0.25, height, 0)
	add_child(leaves)
	_cylinder(point + Vector3(0, height * 0.5, 0), 0.16, height, bark).visible = false
	_obstacles.append(Rect2(Vector2(point.x - 0.55, point.z - 0.55), Vector2(1.1, 1.1)))


func _canal_and_dock() -> void:
	var water := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(90, 600)
	mesh.subdivide_width = 48
	mesh.subdivide_depth = 100
	water.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water.gdshader")
	water.material_override = material
	water.position = Vector3(120, -0.5, 0)
	add_child(water)
	var wood := AssetLibrary.pbr("wood", 1.5)
	var access_ramp := _box(Vector3(66, 0.10, 61), Vector3(2.0, 0.1, 4.0), wood, true, "wood")
	access_ramp.rotation.z = atan2(0.24, 2.0)
	for i: int in range(24):
		_box(Vector3(67 + i * 0.65, 0.16, 61), Vector3(0.6, 0.18, 4.0), wood, true, "wood")
	for x: float in [68.0, 73.0, 79.0, 82.0]:
		for z: float in [59.5, 62.5]:
			_cylinder(Vector3(x, -0.4, z), 0.12, 1.5, wood)
	_boat(Vector3(86, -0.25, 62))
	_prop("basket", Vector3(68, 0.28, 59.6), 0.5, 0.5)


func _boat(point: Vector3) -> void:
	var wood := AssetLibrary.pbr("wood", 1.7)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 24
	var segments := 16
	for row: int in range(rings):
		for col: int in range(segments):
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]:
				var t := float(row + offset.x) / rings
				var a := float(col + offset.y) / segments * PI
				var width := pow(sin(t * PI), 0.5) * 1.15 + 0.02
				surface.add_vertex(Vector3(cos(a) * width, -sin(a) * 0.55 + pow(absf(t - 0.5) * 2, 3) * 0.7, (t - 0.5) * 8.0))
	surface.generate_normals()
	var hull := MeshInstance3D.new()
	hull.mesh = surface.commit()
	var material := wood.duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = material
	hull.position = point
	hull.rotation.y = 0.2
	add_child(hull)
	for i: int in range(5):
		_box(point + Vector3(0, -0.1, -2 + i), Vector3(1.8, 0.12, 0.22), wood, false)


func _portal(point: Vector3) -> void:
	var metal := AssetLibrary.pbr("metal", 1.0)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.53
	mesh.outer_radius = 1.74
	mesh.rings = 96
	mesh.ring_segments = 12
	ring.mesh = mesh
	ring.material_override = metal
	ring.rotation.x = PI * 0.5
	ring.position = point + Vector3(0, 1.85, 0)
	add_child(ring)
	for side: float in [-1.0, 1.0]:
		_box(point + Vector3(side * 1.95, 1.3, 0), Vector3(0.28, 2.6, 0.5), metal)
		_box(point + Vector3(side * 1.95, 1.3, 0.28), Vector3(0.025, 1.8, 0.015), AssetLibrary.emissive(Color(0.43, 0.71, 0.75), 1.5), false)
	var field := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(3.1, 3.1)
	field.mesh = plane
	var field_material := _temporal_material()
	field.material_override = field_material
	field.position = point + Vector3(0, 1.85, 0)
	add_child(field)
	_field_materials.append(field_material)
	_light(point + Vector3(0, 1.8, 0.7), Color(0.5, 0.83, 0.86), 2.0, 5.0)


func _temporal_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/temporal_field.gdshader")
	return material


func _anchor(point: Vector3) -> void:
	var metal := AssetLibrary.pbr("metal", 0.7)
	_cylinder(point + Vector3(0, 0.14, 0), 0.58, 0.28, metal)
	_cylinder(point + Vector3(0, 0.6, 0), 0.13, 0.72, metal)
	_cylinder(point + Vector3(0, 0.98, 0), 0.37, 0.04, AssetLibrary.emissive(Color(0.47, 0.81, 0.83), 1.8), false)
	_anchor_light = _light(point + Vector3(0, 0.95, 0), Color(0.4, 0.75, 0.79), 1.8, 3)
	_label("MERIDIAN / ANCLA 001", point + Vector3(0, 1.3, 0), 0.0025, Color(0.63, 0.8, 0.82))


func _device(point: Vector3) -> void:
	var metal := AssetLibrary.pbr("metal", 0.8)
	_box(point + Vector3(0, 0.32, 0), Vector3(0.65, 0.64, 0.65), metal)
	for i: int in range(4):
		_box(point + Vector3(0, 0.13 + i * 0.14, 0.34), Vector3(0.52, 0.04, 0.025), AssetLibrary.solid(Color(0.035, 0.04, 0.045), 0.5, 0.8), false)
	_resonator_lens = _cylinder(point + Vector3(0, 0.74, 0), 0.13, 0.2, AssetLibrary.emissive(Color(0.8, 0.44, 0.19), 1.0), false)


func _terminal(point: Vector3, text: String, accent: StandardMaterial3D) -> void:
	var metal := AssetLibrary.pbr("metal", 1.5)
	var dark := AssetLibrary.solid(Color(0.024, 0.037, 0.045), 0.55, 0.45)
	_box(point + Vector3(0, 0.65, 0), Vector3(1.6, 1.3, 0.8), metal)
	_box(point + Vector3(0, 1.42, -0.12), Vector3(1.65, 0.92, 0.12), dark)
	_box(point + Vector3(0, 1.42, -0.045), Vector3(1.49, 0.76, 0.014), AssetLibrary.emissive(Color(0.035, 0.075, 0.092), 0.8), false)
	_label(text, point + Vector3(0, 1.43, -0.028), 0.0025, Color(0.64, 0.82, 0.84))
	_box(point + Vector3(0, 1.9, -0.12), Vector3(1.4, 0.025, 0.035), accent, false)


func _navigation_mesh() -> void:
	var nav := NavigationMesh.new()
	nav.agent_radius = 0.35
	nav.agent_height = 1.8
	var vertices := PackedVector3Array()
	var columns := 72
	var rows := 56
	var origin := Vector2(-62, -38)
	var step := 2.0
	for z: int in range(rows + 1):
		for x: int in range(columns + 1):
			var point := origin + Vector2(x * step, z * step)
			var height := 0.04
			if point.x >= 66.0 and point.y >= 60.0 and point.y <= 62.0:
				height += 0.15 if point.x == 66.0 else 0.25
			vertices.append(Vector3(point.x, height, point.y))
	nav.vertices = vertices
	for z: int in range(rows):
		for x: int in range(columns):
			var center := origin + Vector2((x + 0.5) * step, (z + 0.5) * step)
			if _blocked(center, 1.1):
				continue
			var on_dock := center.y > 60.0 and center.y < 62.0
			# The raised dock is accessible only through its western ramp.
			if center.x > 64.0 and center.y > 56.0 and center.y < 66.0 and not on_dock:
				continue
			if center.x > 74.0 and not on_dock:
				continue
			var a := z * (columns + 1) + x
			nav.add_polygon(PackedInt32Array([a, a + columns + 1, a + columns + 2, a + 1]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav
	add_child(region)


func _blocked(point: Vector2, extra: float = 0.0) -> bool:
	for obstacle: Rect2 in _obstacles:
		if obstacle.grow(extra).has_point(point):
			return true
	return false


func _npc(id: String, display_name: String, point: Vector3, yaw: float, fugitive: bool = false) -> TemporalNPC:
	var npc := TemporalNPC.new()
	npc.npc_id = id
	npc.display_name = display_name
	npc.suspect = fugitive
	npc.position = point
	npc.rotation.y = yaw
	add_child(npc)
	return npc


func _interaction(id: String, kind: String, display_name: String, point: Vector3) -> TemporalInteractable:
	var interactable := TemporalInteractable.new()
	interactable.interaction_id = id
	interactable.kind = kind
	interactable.display_name = display_name
	interactable.position = point
	add_child(interactable)
	return interactable


func _prop(id: String, point: Vector3, height: float, yaw: float = 0.0, collision: bool = false) -> Node3D:
	var wrapper := Node3D.new()
	var model := AssetLibrary.model(id)
	wrapper.add_child(model)
	var bounds := AssetLibrary.bounds(model)
	var factor := height / maxf(bounds.size.y, 0.001)
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * factor, -bounds.position.y * factor, -(bounds.position.z + bounds.size.z * 0.5) * factor)
	wrapper.position = point
	wrapper.rotation.y = yaw
	add_child(wrapper)
	if zone == "egypt" and id in ["pottery", "vase"]:
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var geometry := node as MeshInstance3D
			for index: int in range(geometry.mesh.get_surface_count()):
				var source := geometry.get_active_material(index) as StandardMaterial3D
				if source != null:
					var clay := source.duplicate() as StandardMaterial3D
					clay.albedo_color = Color(0.65, 0.32, 0.16)
					clay.roughness = 0.92
					clay.metallic = 0.0
					geometry.set_surface_override_material(index, clay)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(bounds.size.x, bounds.size.y, bounds.size.z) * factor
		shape.shape = box
		shape.position.y = height * 0.5
		body.add_child(shape)
		wrapper.add_child(body)
		if zone == "egypt":
			var radius := Vector2(box.size.x, box.size.z).length() * 0.5 + 0.35
			_obstacles.append(Rect2(Vector2(point.x - radius, point.z - radius), Vector2.ONE * radius * 2.0))
	return wrapper


func _box(point: Vector3, size: Vector3, material: Material, collision: bool = true, surface: String = "stone") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = point
	add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.set_meta("surface", surface)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		instance.add_child(body)
	return instance


func _cylinder(point: Vector3, radius: float, height: float, material: Material, collision: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.94
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	instance.mesh = mesh
	instance.material_override = material
	instance.position = point
	add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = height
		shape.shape = cylinder
		body.add_child(shape)
		instance.add_child(body)
	return instance


func _light(point: Vector3, color: Color, energy: float, distance: float, shadows: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.shadow_enabled = shadows
	add_child(light)
	return light


func _label(text: String, point: Vector3, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font = load("res://assets/fonts/manrope.ttf")
	label.text = text
	label.font_size = 40
	label.pixel_size = pixel_size
	label.modulate = color
	label.position = point
	label.outline_size = 0
	add_child(label)
	return label


func location_name(point: Vector3) -> String:
	var nearest := "Meseta de Guiza" if zone == "egypt" else "Centro de operaciones"
	var distance := 19.0
	for landmark: Dictionary in landmarks:
		var to_landmark := point.distance_to(landmark["position"])
		if to_landmark < distance:
			nearest = String(landmark["name"])
			distance = to_landmark
	return nearest


func map_obstacles() -> Array[Rect2]:
	return _obstacles.duplicate()


func sync_case_state() -> void:
	if is_instance_valid(_resonator_lens) and CaseState.neutralized:
		_resonator_lens.material_override = AssetLibrary.solid(Color(0.07, 0.09, 0.1), 0.6, 0.4)
	if is_instance_valid(_anchor_light):
		_anchor_light.light_color = Color(0.67, 0.9, 0.71) if CaseState.repaired else Color(0.4, 0.75, 0.79)


func _custody_room() -> void:
	var frame := AssetLibrary.pbr("metal", 1.2)
	for x: float in [5.8, 9.6]:
		_box(Vector3(x, 1.45, 7.0), Vector3(0.1, 2.9, 3.6), frame)
	_box(Vector3(7.7, 2.9, 7), Vector3(3.9, 0.12, 3.6), frame)
	var glass := AssetLibrary.solid(Color(0.25, 0.4, 0.43, 0.16), 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(7.7, 1.45, 8.8), Vector3(3.75, 2.8, 0.04), glass)
	_label("CUSTODIA TEMPORAL / MV-09", Vector3(7.7, 3.17, 8.8), 0.003, Color(0.65, 0.82, 0.82))
	_npc("vale", "Marcus Vale", Vector3(7.7, 0.04, 7), -1.25, true)
	_light(Vector3(7.5, 2.5, 7.8), Color(0.69, 0.82, 0.9), 1.6, 4)


func _bootprint(point: Vector3) -> void:
	var image := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	for y: int in range(256):
		for x: int in range(128):
			var u := (x + 0.5) / 128.0 * 2.0 - 1.0
			var v := (y + 0.5) / 256.0
			var toe := pow(u / 0.74, 2) + pow((v - 0.28) / 0.27, 2) < 1.0
			var heel := pow(u / 0.58, 2) + pow((v - 0.81) / 0.16, 2) < 1.0
			if not toe and not heel:
				continue
			var tread := 0.6 if int(v * 29.0) % 2 == 0 else 0.15
			var grain := sin(x * 12.1 + y * 4.7) * 0.08
			image.set_pixel(x, y, Color(0.29, 0.2, 0.12, clampf(tread + grain, 0, 1)))
	var decal := Decal.new()
	decal.texture_albedo = ImageTexture.create_from_image(image)
	decal.size = Vector3(0.19, 0.3, 0.36)
	decal.position = point + Vector3(0, 0.05, 0)
	decal.rotation.y = -0.12
	add_child(decal)
