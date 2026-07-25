shader_type canvas_item;

uniform float tile_size : hint_range(2.0, 64.0) = 8.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 tile_center = (floor(uv * tile_size) + 0.5) / tile_size;
	vec4 color = texture(TEXTURE, tile_center);
	COLOR = mix(texture(TEXTURE, uv), color, amount);
}
