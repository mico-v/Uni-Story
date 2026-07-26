shader_type canvas_item;

// Mono — convert to monochrome (single channel luminance grayscale).
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(gray), amount);
	COLOR = col;
}
