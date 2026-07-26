shader_type canvas_item;

// Rand Roll — random pixel rolling/drift across the screen.
uniform float intensity : hint_range(0.0, 1.0) = 0.1;
uniform float speed : hint_range(0.1, 5.0) = 1.5;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	float seed = floor(TIME * speed + UV.y * 50.0);
	float dx = random(vec2(seed, UV.y)) * intensity * 2.0 - intensity;
	float dy = random(vec2(UV.x, seed)) * intensity * 0.5;
	vec2 offset = vec2(dx, dy);
	COLOR = texture(TEXTURE, clamp(UV + offset, vec2(0.0), vec2(1.0)));
}
