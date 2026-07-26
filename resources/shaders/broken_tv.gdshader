shader_type canvas_item;

// Broken TV — CRT television malfunction effect: scanlines, static, glitch.
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float scanlines : hint_range(0.0, 1.0) = 0.3;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec4 col = texture(TEXTURE, uv);

	// Glitch horizontal displacement
	float glitch_line = step(0.9, random(vec2(floor(UV.y * 100.0), floor(TIME * speed))));
	float glitch_offset = random(vec2(floor(TIME * speed * 3.0), floor(UV.y * 100.0))) * 0.1 * intensity;
	uv.x += glitch_line * glitch_offset;

	col = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));

	// Scanlines
	float scan = sin(UV.y * 400.0) * 0.5 + 0.5;
	col.rgb *= 1.0 - scanlines * (1.0 - scan) * 0.5;

	// Static noise
	float noise = random(uv * floor(TIME * speed * 10.0)) * intensity * 0.3;
	col.rgb += noise;
	col.rgb = clamp(col.rgb, 0.0, 1.0);

	COLOR = col;
}
