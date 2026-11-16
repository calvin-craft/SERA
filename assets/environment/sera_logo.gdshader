shader_type canvas_item;
render_mode unshaded;

uniform float reflection_position = -0.22;

void fragment() {
	float distance_to_reflection = abs(UV.x + 0.20 * (UV.y - 0.5) - reflection_position);
	float broad = 1.0 - smoothstep(0.015, 0.095, distance_to_reflection);
	float edge = 1.0 - smoothstep(0.002, 0.030, distance_to_reflection);
	vec3 metal = COLOR.rgb * vec3(0.984, 0.992, 1.0);
	vec3 reflection = (vec3(1.0) - metal) * vec3(0.82, 0.92, 1.0);
	COLOR.rgb = metal + reflection * (0.25 * broad + 0.43 * edge);
}
