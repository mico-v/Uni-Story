shader_type canvas_item;

// Motion Blur — directional blur simulating movement along a velocity vector.
uniform vec2 direction = vec2(1.0, 0.0);
uniform float strength : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec2 texel = vec2(1.0 / float(textureSize(TEXTURE, 0).x), 1.0 / float(textureSize(TEXTURE, 0).y));
	vec2 dir = normalize(direction) * texel * strength;

	vec4 col = vec4(0.0);
	float total = 0.0;
	int samples = 8;

	for (int i = 0; i < 8; i++) {
		float t = float(i) / float(samples - 1);
		float weight = 1.0 - abs(t - 0.5) * 2.0; // triangle filter
		col += texture(TEXTURE, UV - dir * t) * weight;
		total += weight;
	}

	COLOR = col / total;
}
