shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float pixel_size : hint_range(1.0, 64.0) = 8.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_uv = floor(uv * pixel_size) / pixel_size;
	vec4 color = texture(SCREEN_TEXTURE, pixel_uv);
	COLOR = mix(texture(SCREEN_TEXTURE, uv), color, amount);
}
