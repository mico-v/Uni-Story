shader_type canvas_item;

// Final Blit — simple pass-through used as compositing final stage.
// Copies TEXTURE → COLOR with optional global tint.
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	col.rgb = mix(col.rgb, tint_color.rgb, tint_amount);
	COLOR = col;
}
