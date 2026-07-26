shader_type canvas_item;

// Ripple Move — animated ripple distortion that moves across the screen.
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.1, 5.0) = 2.0;
uniform float frequency : hint_range(0.5, 20.0) = 8.0;
uniform float phase_offset : hint_range(0.0, 6.28) = 0.0;

void fragment() {
	vec2 center = vec2(0.5 + sin(TIME * speed * 0.5 + phase_offset) * 0.3, 0.5 + cos(TIME * speed * 0.3) * 0.2);
	float dist = distance(UV, center);
	float ripple = sin(dist * frequency - TIME * speed + phase_offset) * intensity * 0.03;
	vec2 offset = normalize(UV - center) * ripple;
	COLOR = texture(TEXTURE, clamp(UV + offset, vec2(0.0), vec2(1.0)));
}
