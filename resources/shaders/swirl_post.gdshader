shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float strength : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);
	float angle = atan(uv.y - center.y, uv.x - center.x);
	float offset = strength * 0.02 * amount;
	vec2 offset_uv = vec2(cos(angle + offset), sin(angle + offset)) * dist + center;
	COLOR = texture(SCREEN_TEXTURE, offset_uv);
}
