shader_type spatial;
render_mode cull_disabled;

uniform vec4 water_color : source_color = vec4(0.15, 0.22, 0.18, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = world_position.x * 0.8 + TIME * 0.65;
	float b = world_position.z * 1.35 - TIME * 0.4;
	VERTEX.y += sin(a) * 0.045 + sin(b) * 0.025;
	NORMAL = normalize(vec3(-cos(a) * 0.036, 1.0, -cos(b) * 0.034));
}

void fragment() {
	float ripple = sin(world_position.x * 3.0 + world_position.z * 2.0 + TIME) * 0.015;
	ALBEDO = water_color.rgb + vec3(ripple);
	ROUGHNESS = 0.19;
	METALLIC = 0.08;
	SPECULAR = 0.6;
}
