shader_type canvas_item;

// Gaussian blur — works on both per-object (TEXTURE) and full-screen (SCREEN_TEXTURE).
// amount = 0 → no blur, amount = 10 → heavy blur.
uniform float amount : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	if (amount < 0.01) {
		COLOR = texture(TEXTURE, UV);
	} else {

	// 9-tap Gaussian approximation using TEXTURE (works per-object).
	float blur = amount * 0.5 / max(float(textureSize(TEXTURE, 0).x), 1.0);

	vec4 c = texture(TEXTURE, UV) * 0.227027;
	c += texture(TEXTURE, UV + vec2( blur * 1.0, 0.0)) * 0.1945946;
	c += texture(TEXTURE, UV + vec2(-blur * 1.0, 0.0)) * 0.1945946;
	c += texture(TEXTURE, UV + vec2( blur * 2.0, 0.0)) * 0.1216216;
	c += texture(TEXTURE, UV + vec2(-blur * 2.0, 0.0)) * 0.1216216;
	c += texture(TEXTURE, UV + vec2( blur * 3.0, 0.0)) * 0.054054;
	c += texture(TEXTURE, UV + vec2(-blur * 3.0, 0.0)) * 0.054054;
	c += texture(TEXTURE, UV + vec2( blur * 4.0, 0.0)) * 0.016216;
	c += texture(TEXTURE, UV + vec2(-blur * 4.0, 0.0)) * 0.016216;

	// Vertical pass
	vec4 c2 = texture(TEXTURE, UV) * 0.227027;
	c2 += texture(TEXTURE, UV + vec2(0.0,  blur * 1.0)) * 0.1945946;
	c2 += texture(TEXTURE, UV + vec2(0.0, -blur * 1.0)) * 0.1945946;
	c2 += texture(TEXTURE, UV + vec2(0.0,  blur * 2.0)) * 0.1216216;
	c2 += texture(TEXTURE, UV + vec2(0.0, -blur * 2.0)) * 0.1216216;
	c2 += texture(TEXTURE, UV + vec2(0.0,  blur * 3.0)) * 0.054054;
	c2 += texture(TEXTURE, UV + vec2(0.0, -blur * 3.0)) * 0.054054;
	c2 += texture(TEXTURE, UV + vec2(0.0,  blur * 4.0)) * 0.016216;
	c2 += texture(TEXTURE, UV + vec2(0.0, -blur * 4.0)) * 0.016216;

	COLOR = mix(c, c2, 0.5);

	}
}
