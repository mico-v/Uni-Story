shader_type canvas_item;

// Blink — rapid flashing / strobe effect using TIME.
uniform float speed : hint_range(0.5, 20.0) = 5.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float blink = abs(sin(TIME * speed));
	blink = step(0.5, blink);
	col.rgb = mix(col.rgb, vec3(1.0), blink * strength);
	COLOR = col;
}
