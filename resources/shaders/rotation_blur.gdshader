shader_type canvas_item;

// Rotation Blur — radial/circular motion blur around the screen center.
uniform float strength : hint_range(0.0, 10.0) = 2.0;
uniform float center_x : hint_range(0.0, 1.0) = 0.5;
uniform float center_y : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 center = vec2(center_x, center_y);
	vec2 delta = UV - center;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);

	vec4 col = vec4(0.0);
	float total = 0.0;
	float max_angle = strength * 0.05;
	int samples = 6;

	for (int i = 0; i < 6; i++) {
		float t = float(i) / float(samples - 1) - 0.5;
		float a = angle + max_angle * t;
		vec2 sample_uv = center + vec2(cos(a), sin(a)) * dist;
		float weight = 1.0 - abs(t) * 2.0;
		col += texture(TEXTURE, sample_uv) * weight;
		total += weight;
	}

	COLOR = col / total;
}
