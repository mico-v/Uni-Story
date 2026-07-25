shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 64.0) = 16.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 pixel_uv = floor(uv * pixel_size) / pixel_size;
	vec4 color = texture(TEXTURE, pixel_uv);
	COLOR = mix(texture(TEXTURE, uv), color, amount);
}
