shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform float riot : hint_range(0.0, 1.0) = 0.0;

varying vec3 albedo_color;

void vertex() {
	float phase = float(INSTANCE_ID) * 0.37;
	float walk = sin(TIME * 5.2 + phase);
	float arm = smoothstep(0.95, 1.22, VERTEX.y) * smoothstep(0.14, 0.32, abs(VERTEX.x));
	VERTEX.z += walk * sign(VERTEX.x) * arm * 0.18;
	VERTEX.y += abs(walk) * 0.03;
	albedo_color = mix(COLOR.rgb, vec3(0.55, 0.12, 0.08), riot);
}

void fragment() {
	ALBEDO = albedo_color;
	ROUGHNESS = 0.86;
}
