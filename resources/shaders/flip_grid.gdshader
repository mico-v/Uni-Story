shader_type canvas_item;

// Flip Grid — animates a page-turn-like grid flip, splitting the screen into
// horizontal strips that flip independently.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float rows : hint_range(1.0, 20.0) = 4.0;
uniform float amplitude : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	float row = floor(UV.y * rows);
	float row_center = (row + 0.5) / rows;
	float distance_to_center = UV.y - row_center;
	float row_progress = clamp((progress * rows - row) / 1.0, 0.0, 1.0);

	// Perspective-like compression
	float perspective = 1.0 - row_progress * amplitude;
	float x_offset = sin(UV.y * 3.14159 * rows) * row_progress * amplitude;

	vec2 uv = UV;
	uv.y = row_center + distance_to_center * perspective;
	uv.x += x_offset;

	// Mirror past the flip midpoint
	if (row_progress > 0.5) {
		uv.x = UV.x + (1.0 - row_progress) * x_offset;
	}

	uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 col = texture(TEXTURE, uv);

	// Darken during flip
	col.rgb *= 1.0 - row_progress * 0.5;

	COLOR = col;
}
