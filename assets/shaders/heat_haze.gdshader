shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

void fragment() {
	float wave = sin(UV.x * 28.0 + TIME * 1.6) * sin(UV.y * 12.0 - TIME * 0.7);
	ALBEDO = vec3(0.95, 0.78, 0.46);
	ALPHA = clamp(0.03 + wave * 0.015, 0.0, 0.08);
}
