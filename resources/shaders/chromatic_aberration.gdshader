shader_type canvas_item;

// Chromatic aberration — splits RGB channels by pixel offset.
// amount = 0 → no effect, amount = 10 → strong color fringing.
uniform float amount : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	if (amount < 0.01) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
		vec2 offset = vec2(amount * texel.x, 0.0);

		float r = texture(TEXTURE, UV + offset).r;
		float g = texture(TEXTURE, UV).g;
		float b = texture(TEXTURE, UV - offset).b;
		float a = texture(TEXTURE, UV).a;

		COLOR = vec4(r, g, b, a);
	}
}
