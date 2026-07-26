shader_type canvas_item;

// Shake — screen shake with configurable axis and decay.
uniform vec2 intensity = vec2(0.05, 0.05);
uniform float speed : hint_range(0.5, 20.0) = 10.0;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	float seed = floor(TIME * speed + UV.y * 100.0);
	float dx = random(vec2(seed, UV.y)) * 2.0 - 1.0;
	float dy = random(vec2(UV.x, seed)) * 2.0 - 1.0;
	vec2 offset = vec2(dx * intensity.x, dy * intensity.y);
	COLOR = texture(TEXTURE, clamp(UV + offset, vec2(0.0), vec2(1.0)));
}
