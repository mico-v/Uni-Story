shader_type canvas_item;

// Roll — rolling/rotating screen effect (like a barrel roll).
uniform float angle : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 delta = UV - center;
	float a = angle * 3.14159265;
	float s = sin(a);
	float c = cos(a);
	vec2 rotated = vec2(delta.x * c - delta.y * s, delta.x * s + delta.y * c) + center;
	COLOR = texture(TEXTURE, clamp(rotated, vec2(0.0), vec2(1.0)));
}
