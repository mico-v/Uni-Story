shader_type canvas_item;

// Mix Add — additive blending of two textures, with optional mask.
// Nova-compatible: the `_Mask` parameter (a Masks/xxx path) controls where
// the additive blend is applied.
uniform sampler2D second_tex : hint_default_white;
uniform float strength : hint_range(0.0, 2.0) = 0.5;
uniform sampler2D mask : hint_default_white;

void fragment() {
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(second_tex, UV);
	float m = texture(mask, UV).r;
	vec4 result = a + b * strength * m;
	result = clamp(result, 0.0, 1.0);
	COLOR = result;
}
