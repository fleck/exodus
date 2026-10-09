shader_type spatial;

uniform vec4 sand_hi : source_color = vec4(0.79, 0.63, 0.38, 1.0);
uniform vec4 sand_lo : source_color = vec4(0.50, 0.34, 0.20, 1.0);

void fragment() {
	float grain = sin(UV.x * 48.0) * sin(UV.y * 36.0);
	float slope = clamp(NORMAL.y, 0.0, 1.0);
	ALBEDO = mix(sand_lo.rgb, sand_hi.rgb, slope) + vec3(grain * 0.015);
	ROUGHNESS = 0.95;
}
