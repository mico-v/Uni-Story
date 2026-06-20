shader_type canvas_item;

// Vignette darkening around screen edges.
// intensity = 0 → no vignette, intensity = 1 → fully black edges.
// radius = how far from center the darkening starts (0 = center, 1 = edge).
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float radius : hint_range(0.0, 1.5) = 0.7;
uniform float softness : hint_range(0.01, 2.0) = 0.4;

void fragment() {
	vec4 c = texture(TEXTURE, UV);

	vec2 center = vec2(0.5);
	float dist = distance(UV, center);
	float vignette = smoothstep(radius, radius - softness, dist);
	c.rgb *= mix(1.0, vignette, intensity);

	COLOR = c;
}
