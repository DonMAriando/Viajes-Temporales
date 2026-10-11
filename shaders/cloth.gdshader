shader_type spatial;
render_mode cull_disabled;

uniform sampler2D cloth_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.93, 0.86, 0.67, 1.0);

void vertex() {
	float pinned = sin(UV.x * 3.14159265) * sin(UV.y * 3.14159265);
	VERTEX.y += sin(TIME * 1.6 + VERTEX.x * 1.7 + VERTEX.z) * 0.035 * pinned;
}

void fragment() {
	ALBEDO = texture(cloth_albedo, UV * 3.0).rgb * tint.rgb;
	NORMAL_MAP = texture(cloth_normal, UV * 3.0).rgb;
	NORMAL_MAP_DEPTH = 0.45;
	ROUGHNESS = 0.94;
}
