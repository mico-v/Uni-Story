shader_type canvas_item;

// Ripple effect — radial wave distortion from center.
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.1, 5.0) = 2.0;
uniform float frequency : hint_range(0.5, 20.0) = 8.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float ripple = sin(dist * frequency - TIME * speed) * intensity * 0.03;
	vec2 offset = normalize(UV - center) * ripple;
	COLOR = texture(TEXTURE, UV + offset);
}
