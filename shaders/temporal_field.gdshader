shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 field_color : source_color = vec4(0.42, 0.75, 0.78, 1.0);
uniform float strength = 0.24;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float edge = smoothstep(0.5, 1.0, radius);
	float wave = sin(radius * 45.0 - TIME * 2.5 + sin(p.y * 14.0 + TIME) * 0.4);
	ALBEDO = field_color.rgb;
	EMISSION = field_color.rgb * (0.12 + edge * 0.8);
	ALPHA = (0.05 + edge * 0.22 + wave * 0.025) * strength * (1.0 - smoothstep(0.96, 1.0, radius));
}
