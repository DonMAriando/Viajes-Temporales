shader_type spatial;
render_mode cull_disabled;

void vertex() {
	VERTEX.x += sin(TIME * 1.1 + VERTEX.z * 2.0) * 0.025 * UV.y;
}

void fragment() {
	float rib = exp(-abs(UV.x - 0.5) * 60.0);
	float vein = sin(UV.y * 145.0 + UV.x * 25.0) * 0.025;
	vec3 green = mix(vec3(0.12, 0.19, 0.055), vec3(0.25, 0.32, 0.10), rib);
	ALBEDO = mix(green + vec3(vein), vec3(0.36, 0.30, 0.12), smoothstep(0.82, 1.0, UV.y) * 0.4);
	ROUGHNESS = 0.65;
	BACKLIGHT = ALBEDO * 0.22;
}
