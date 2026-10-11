shader_type canvas_item;

void fragment() {
	float left = 1.0 - smoothstep(0.0, 0.78, UV.x);
	float vignette = pow(length(UV - vec2(0.5)) * 1.2, 2.0);
	COLOR = vec4(0.012, 0.025, 0.034, clamp(left * 0.82 + vignette * 0.3, 0.0, 0.97));
}
