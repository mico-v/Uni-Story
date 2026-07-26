shader_type canvas_item;

// Fade — simple alpha fade (screen darken / brighten).
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	col = mix(col, fade_color, amount);
	COLOR = col;
}
