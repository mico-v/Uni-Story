shader_type canvas_item;

// Fade Radial Blur — fade with radial zoom into blur.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float blur_size : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 delta = UV - center;
	float dist = length(delta);

	float blur = blur_size * amount;
	vec2 texel = vec2(1.0 / float(textureSize(TEXTURE, 0).x), 1.0 / float(textureSize(TEXTURE, 0).y));

	vec4 col = vec4(0.0);
	float total = 0.0;

	for (int i = 0; i < 5; i++) {
		float t = float(i) * 0.2 * dist;
		vec2 offset = normalize(delta) * blur * t;
		float w = 1.0 - t * 2.0;
		w = max(w, 0.0);
		col += texture(TEXTURE, UV + offset) * w;
		total += w;
	}

	col /= max(total, 0.01);
	col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), 1.0 - total * 0.5);
	COLOR = col;
}
