shader_type canvas_item;

uniform float segments : hint_range(2.0, 32.0) = 6.0;
uniform float angle_offset : hint_range(0.0, 6.28318) = 0.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float angle = atan(uv.y, uv.x) - angle_offset;
	float segment_angle = 6.28318 / segments;
	angle = mod(angle, segment_angle * 2.0);
	if (angle > segment_angle) {
		angle = segment_angle * 2.0 - angle;
	}
	float radius = length(uv);
	vec2 mirrored_uv = vec2(cos(angle), sin(angle)) * radius + 0.5;
	vec4 color = texture(TEXTURE, mirrored_uv);
	COLOR = mix(texture(TEXTURE, UV), color, amount);
}
