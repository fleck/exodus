shader_type spatial;
render_mode diffuse_lambert;

uniform float riot : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float phase = VERTEX.x * 2.3 + VERTEX.z * 1.7;
	VERTEX.y += abs(sin(TIME * 5.0 + phase)) * 0.07;
	VERTEX.x += sin(TIME * 2.4 + phase) * 0.03;
}

void fragment() {
	ALBEDO = mix(vec3(0.45, 0.30, 0.20), vec3(0.58, 0.14, 0.09), riot);
	ROUGHNESS = 0.9;
}
