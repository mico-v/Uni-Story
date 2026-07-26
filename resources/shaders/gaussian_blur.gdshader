shader_type canvas_item;

// Gaussian Blur — full 9-sample horizontal + vertical Gaussian blur.
// Higher quality than the simple blur shader; suitable for screen-space post-processing.
uniform vec2 blur_size = vec2(4.0, 0.0);

void fragment() {
	vec2 texel = vec2(1.0 / float(textureSize(TEXTURE, 0).x), 1.0 / float(textureSize(TEXTURE, 0).y));
	vec2 size = blur_size * texel;

	vec4 c = texture(TEXTURE, UV) * 0.227027;
	c += texture(TEXTURE, UV + vec2(size.x, 0.0)) * 0.1945946;
	c += texture(TEXTURE, UV - vec2(size.x, 0.0)) * 0.1945946;
	c += texture(TEXTURE, UV + vec2(size.x * 2.0, 0.0)) * 0.1216216;
	c += texture(TEXTURE, UV - vec2(size.x * 2.0, 0.0)) * 0.1216216;
	c += texture(TEXTURE, UV + vec2(size.x * 3.0, 0.0)) * 0.054054;
	c += texture(TEXTURE, UV - vec2(size.x * 3.0, 0.0)) * 0.054054;
	c += texture(TEXTURE, UV + vec2(size.x * 4.0, 0.0)) * 0.016216;
	c += texture(TEXTURE, UV - vec2(size.x * 4.0, 0.0)) * 0.016216;

	vec4 c2 = texture(TEXTURE, UV) * 0.227027;
	c2 += texture(TEXTURE, UV + vec2(0.0, size.y)) * 0.1945946;
	c2 += texture(TEXTURE, UV - vec2(0.0, size.y)) * 0.1945946;
	c2 += texture(TEXTURE, UV + vec2(0.0, size.y * 2.0)) * 0.1216216;
	c2 += texture(TEXTURE, UV - vec2(0.0, size.y * 2.0)) * 0.1216216;
	c2 += texture(TEXTURE, UV + vec2(0.0, size.y * 3.0)) * 0.054054;
	c2 += texture(TEXTURE, UV - vec2(0.0, size.y * 3.0)) * 0.054054;
	c2 += texture(TEXTURE, UV + vec2(0.0, size.y * 4.0)) * 0.016216;
	c2 += texture(TEXTURE, UV - vec2(0.0, size.y * 4.0)) * 0.016216;

	COLOR = mix(c, c2, 0.5);
}
