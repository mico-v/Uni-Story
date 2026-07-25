shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color.rgb = mix(color.rgb, 1.0 - color.rgb, amount);
	COLOR = color;
}
