shader_type canvas_item;

// Lens Blur — depth-of-field style blur with bokeh-like shape sampling.
// Uses a disc-shaped kernel for more photographic look.
uniform float size : hint_range(0.0, 10.0) = 3.0;
uniform float bokeh : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 texel = vec2(1.0 / float(textureSize(TEXTURE, 0).x), 1.0 / float(textureSize(TEXTURE, 0).y));
	vec4 col = vec4(0.0);
	float total = 0.0;
	int samples = 16;

	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 2.0 * 3.14159265 / float(samples);
		float radius = size * bokeh * 0.5;
		vec2 offset = vec2(cos(angle), sin(angle)) * radius * texel;

		// Inner ring
		float w1 = 1.0;
		col += texture(TEXTURE, UV + offset) * w1;
		total += w1;

		// Outer ring (disc shape)
		float w2 = 0.5;
		col += texture(TEXTURE, UV + offset * 2.0) * w2;
		total += w2;
	}

	COLOR = col / total;
}
