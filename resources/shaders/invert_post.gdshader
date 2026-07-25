shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
	color.rgb = mix(color.rgb, 1.0 - color.rgb, amount);
	COLOR = color;
}
