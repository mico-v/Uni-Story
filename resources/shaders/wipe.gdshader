shader_type canvas_item;

// Wipe transition — sweeps a solid color across the screen along an angle.
// progress = 0 → fully transparent, progress = 1 → fully covered.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;
uniform vec4 wipe_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float edge_softness : hint_range(0.0, 0.3) = 0.05;

void fragment() {
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));

	// Project UV position onto the wipe direction.
	float proj = dot(UV - vec2(0.5), dir) + 0.5;

	// Map progress to a sweeping edge.
	float edge = smoothstep(progress - edge_softness, progress + edge_softness, proj);
	float alpha = mix(1.0, edge, 1.0 - (1.0 - progress));

	// Blend between transparent and wipe color.
	float coverage = 1.0 - smoothstep(progress - edge_softness, progress + edge_softness, proj);
	COLOR = vec4(wipe_color.rgb, wipe_color.a * coverage);
}
