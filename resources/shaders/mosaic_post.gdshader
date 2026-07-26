shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float tile_size : hint_range(2.0, 64.0) = 8.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 tile_uv = floor(uv * tile_size) / tile_size;
	vec4 color = texture(SCREEN_TEXTURE, tile_uv);
	COLOR = mix(texture(SCREEN_TEXTURE, uv), color, amount);
}
