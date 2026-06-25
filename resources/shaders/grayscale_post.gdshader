shader_type canvas_item;

// Full-screen grayscale — reads from SCREEN_TEXTURE (the scene behind the rect).
// amount = 0 → original, amount = 1 → full grayscale.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(SCREEN_TEXTURE, SCREEN_UV);
	float luminance = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(luminance), amount), c.a);
}
