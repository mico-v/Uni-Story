shader_type canvas_item;

// Gray Wave — animated grayscale wave scrolling across the screen.
uniform float wave_amount : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float frequency : hint_range(0.5, 10.0) = 3.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float wave = sin(UV.x * frequency * 6.28 + TIME * speed) * 0.5 + 0.5;
	float t = wave * wave_amount;
	col.rgb = mix(col.rgb, vec3(gray), t);
	COLOR = col;
}
