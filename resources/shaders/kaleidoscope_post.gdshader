shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float strength : hint_range(0.0, 5.0) = 2.0;
uniform float segments : hint_range(2.0, 32.0) = 6.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float angle = atan(centered.y, centered.x);
	float segment_angle = 3.14159 * 2.0 / segments;
	float mapped_angle = mod(angle, segment_angle * 2.0);
	if (mapped_angle > segment_angle) {
		mapped_angle = segment_angle * 2.0 - mapped_angle;
	}
	float dist = length(centered);
	vec2 kaleido_uv = vec2(cos(mapped_angle) * dist, sin(mapped_angle) * dist) + 0.5;
	COLOR = mix(texture(SCREEN_TEXTURE, uv), texture(SCREEN_TEXTURE, kaleido_uv), amount);
}
