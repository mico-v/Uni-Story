shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.1, 5.0) = 2.0;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += (random(vec2(floor(SCREEN_UV.y * 50.0), TIME * speed)) - 0.5) * intensity * 0.1;
	vec4 col = texture(SCREEN_TEXTURE, uv);

	float r = texture(SCREEN_TEXTURE, uv + vec2(intensity * 0.02, 0.0)).r;
	float b = texture(SCREEN_TEXTURE, uv - vec2(intensity * 0.02, 0.0)).b;
	col = vec4(r, col.g, b, col.a);
	COLOR = col;
}
