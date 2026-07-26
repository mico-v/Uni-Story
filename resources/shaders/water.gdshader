shader_type canvas_item;

// Water — animated water ripple/displacement effect.
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.1, 5.0) = 2.0;
uniform float wave_count : hint_range(1.0, 10.0) = 3.0;

void fragment() {
	float dx = 0.0;
	float dy = 0.0;
	for (float i = 0.0; i < 3.0; i++) {
		float fi = i + 1.0;
		float phase = TIME * speed * fi * 0.7;
		dx += sin(UV.y * fi * 6.28 + phase) * intensity * 0.01 / fi;
		dy += cos(UV.x * fi * 6.28 + phase) * intensity * 0.01 / fi;
	}
	vec2 offset = vec2(dx, dy);
	COLOR = texture(TEXTURE, clamp(UV + offset, vec2(0.0), vec2(1.0)));
}
