shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(-5.0, 5.0) = 2.0;
uniform float radius : hint_range(0.1, 2.0) = 0.7;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);
	float factor = 1.0 - smoothstep(0.0, radius, dist);
	angle += factor * strength;
	vec2 swirled_uv = vec2(cos(angle), sin(angle)) * dist + 0.5;
	vec4 color = texture(SCREEN_TEXTURE, swirled_uv);
	COLOR = mix(texture(SCREEN_TEXTURE, SCREEN_UV), color, amount);
}
