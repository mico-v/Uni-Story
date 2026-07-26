shader_type canvas_item;

// Show Second Texture — reveals a second texture through a mask or wipe.
uniform sampler2D second_tex : hint_default_white;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float direction : hint_range(0.0, 1.0) = 0.0; // 0=left, 0.25=up, 0.5=right, 0.75=down

void fragment() {
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(second_tex, UV);

	float edge;
	float di = direction;
	if (di < 0.125 || di > 0.875) {
		edge = UV.x;
	} else if (di < 0.375) {
		edge = UV.y;
	} else if (di < 0.625) {
		edge = 1.0 - UV.x;
	} else {
		edge = 1.0 - UV.y;
	}

	float t = smoothstep(progress - 0.02, progress + 0.02, edge);
	COLOR = mix(a, b, t);
}
