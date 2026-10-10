shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.28, 0.36, 0.22, 1.0);
uniform float bitter : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float ripple = sin(UV.x * 24.0 + TIME * 2.0) * sin(UV.y * 18.0 - TIME * 1.4);
	vec3 sweet = vec3(0.28, 0.58, 0.78);
	vec3 murk = water_color.rgb;
	ALBEDO = mix(sweet, murk, bitter) + vec3(ripple * 0.035);
	ROUGHNESS = mix(0.06, 0.32, bitter);
	METALLIC = 0.0;
	SPECULAR = 0.62;
	NORMAL = normalize(NORMAL + vec3(ripple * 0.16, 0.0, ripple * 0.1));
	ALPHA = mix(0.7, 0.84, bitter);
}
