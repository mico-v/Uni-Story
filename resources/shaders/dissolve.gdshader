shader_type canvas_item;

// Dissolve effect — threshold animates from 0 (fully visible) to 1 (fully dissolved).
// Uses a procedural noise pattern when no noise texture is provided.
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture : source_color, filter_nearest;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.03;
uniform float use_texture : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D capture_texture : source_color;
uniform float use_capture : hint_range(0.0, 1.0) = 0.0;

// Simple hash-based procedural noise fallback.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// When capturing, sample the previous frame as the dissolve "from" layer.
	vec4 from_color;
	if (use_capture > 0.5) {
		from_color = texture(capture_texture, UV);
	} else {
		from_color = texture(TEXTURE, UV);
	}
	vec4 to_color = texture(TEXTURE, UV);

	float n;
	if (use_texture > 0.5) {
		n = texture(noise_texture, UV).r;
	} else {
		n = noise(UV * 8.0);
	}

	// Below threshold: show "from" (previous frame or discard).
	// Above threshold: show "to" (current frame).
	vec4 c;
	if (use_capture > 0.5) {
		c = from_color;
		// Reveal "to" above threshold.
		if (n >= threshold) {
			c = to_color;
		}
	} else {
		c = to_color;
		// Discard pixels below threshold.
		if (n < threshold) {
			discard;
		}
	}

	// Edge glow: pixels near the dissolve boundary.
	float edge = smoothstep(threshold, threshold + edge_width, n);
	c.rgb = mix(edge_color.rgb, c.rgb, edge);

	COLOR = c;
}
