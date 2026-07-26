shader_type canvas_item;

// Mix Add — additive blending of two textures.
uniform sampler2D second_tex : hint_default_white;
uniform float strength : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(second_tex, UV);
	vec4 result = a + b * strength;
	result = clamp(result, 0.0, 1.0);
	COLOR = result;
}
