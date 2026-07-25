shader_type canvas_item;

uniform float strength : hint_range(-5.0, 5.0) = 2.0;
uniform float radius : hint_range(0.1, 2.0) = 1.2;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);
	float factor = 1.0 - smoothstep(0.0, radius, dist);
	angle += factor * strength;
	vec2 swirled_uv = vec2(cos(angle), sin(angle)) * dist + 0.5;
	vec4 color = texture(TEXTURE, swirled_uv);
	COLOR = mix(texture(TEXTURE, UV), color, amount);
}
