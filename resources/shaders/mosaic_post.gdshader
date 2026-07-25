shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float tile_size : hint_range(2.0, 64.0) = 8.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 tile_center = (floor(uv * tile_size) + 0.5) / tile_size;
	vec4 color = texture(SCREEN_TEXTURE, tile_center);
	COLOR = mix(texture(SCREEN_TEXTURE, uv), color, amount);
}
