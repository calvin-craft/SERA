shader_type canvas_item;
render_mode unshaded;

uniform sampler2D forward_portrait : source_color, filter_linear_mipmap, repeat_disable;
uniform float look_ahead = 1.0;

void fragment() {
	// Align the forward-facing eye to the same cheek and brow on the wrist pose.
	vec2 from_eye = UV / TEXTURE_PIXEL_SIZE - vec2(462.5, 286.0);
	mat2 alignment = mat2(vec2(0.949, 0.315), vec2(-0.315, 0.949));
	vec2 forward_offset = (alignment * from_eye) * 0.94;
	float eye_region = length((forward_offset + vec2(0.0, 6.0)) / vec2(26.0, 24.0));
	float blend = look_ahead * (1.0 - smoothstep(0.57, 1.0, eye_region));
	vec2 forward_uv = (vec2(498.0, 198.0) + forward_offset) * TEXTURE_PIXEL_SIZE;
	vec4 forward_eye = texture(forward_portrait, forward_uv);
	COLOR.rgb = mix(COLOR.rgb, forward_eye.rgb, blend * forward_eye.a);
}
