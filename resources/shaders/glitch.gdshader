shader_type canvas_item;

// Glitch effect — shifts UV in random horizontal bands.
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.1, 5.0) = 2.0;

void fragment() {
	float shift = sin(UV.y * 50.0 + TIME * speed) * intensity * 0.02;
	vec4 color = texture(TEXTURE, UV + vec2(shift, 0.0));
	// Add color channel separation.
	float r_shift = sin(UV.y * 30.0 + TIME * speed * 1.3) * intensity * 0.03;
	color.r = texture(TEXTURE, UV + vec2(r_shift, 0.0)).r;
	COLOR = color;
}
