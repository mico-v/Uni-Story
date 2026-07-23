shader_type canvas_item;

// Full-screen vignette — reads from SCREEN_TEXTURE (the scene behind the rect).
// intensity = 0 → no vignette, intensity = 1 → fully black edges.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float radius : hint_range(0.0, 1.5) = 0.7;
uniform float softness : hint_range(0.01, 2.0) = 0.4;

void fragment() {
	vec4 c = texture(SCREEN_TEXTURE, SCREEN_UV);

	vec2 center = vec2(0.5);
	float dist = distance(SCREEN_UV, center);
	float vignette = smoothstep(radius, radius - softness, dist);
	c.rgb *= mix(1.0, vignette, intensity);

	COLOR = c;
}
