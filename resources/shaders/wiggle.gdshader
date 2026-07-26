shader_type canvas_item;

// Wiggle — random screen shake/wobble using sine-based displacement.
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.1, 5.0) = 2.0;
uniform float frequency : hint_range(1.0, 20.0) = 8.0;

void fragment() {
	float dx = sin(UV.y * frequency + TIME * speed) * intensity * 0.02;
	float dy = cos(UV.x * frequency + TIME * speed * 1.3) * intensity * 0.02;
	vec2 offset = vec2(dx, dy);
	COLOR = texture(TEXTURE, UV + offset);
}
