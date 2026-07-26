shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, SCREEN_UV);
	float dist = distance(SCREEN_UV, vec2(0.5, 0.5));
	float vignette = smoothstep(0.8, 0.2, dist);
	col.rgb *= mix(1.0, vignette, intensity);
	COLOR = col;
}
