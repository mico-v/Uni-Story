shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 3.0) = 3.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = (uv - 0.5) * amount * 0.03;
	COLOR = texture(SCREEN_TEXTURE, uv + offset);
}
