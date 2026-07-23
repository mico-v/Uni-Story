shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Full-screen chromatic aberration — reads from SCREEN_TEXTURE.
// amount = 0 → no effect, amount = 10 → strong color fringing.
uniform float amount : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	if (amount < 0.01) {
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	} else {
		vec2 texel = 1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));
		vec2 offset = vec2(amount * texel.x, 0.0);

		float r = texture(SCREEN_TEXTURE, SCREEN_UV + offset).r;
		float g = texture(SCREEN_TEXTURE, SCREEN_UV).g;
		float b = texture(SCREEN_TEXTURE, SCREEN_UV - offset).b;
		float a = texture(SCREEN_TEXTURE, SCREEN_UV).a;

		COLOR = vec4(r, g, b, a);
	}
}
