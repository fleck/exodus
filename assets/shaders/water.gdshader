shader_type spatial;

uniform vec4 water_color : source_color = vec4(0.16, 0.42, 0.32, 1.0);
uniform float bitter : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float ripple = sin(UV.x * 24.0 + TIME * 2.0) * sin(UV.y * 18.0 - TIME * 1.4);
	vec3 sweet = vec3(0.22, 0.52, 0.72);
	ALBEDO = mix(sweet, water_color.rgb, bitter) + vec3(ripple * 0.04);
	ROUGHNESS = 0.12;
	METALLIC = 0.35;
	ALPHA = 0.88;
}
