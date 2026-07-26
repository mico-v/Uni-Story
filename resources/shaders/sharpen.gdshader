shader_type canvas_item;

// Sharpen — image sharpening filter using unsharp mask technique.
uniform float strength : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec2 texel = vec2(1.0 / float(textureSize(TEXTURE, 0).x), 1.0 / float(textureSize(TEXTURE, 0).y));
	vec4 center = texture(TEXTURE, UV);
	vec4 blur = texture(TEXTURE, UV + vec2(-texel.x, -texel.y)) * 0.0625;
	blur += texture(TEXTURE, UV + vec2(0.0, -texel.y)) * 0.125;
	blur += texture(TEXTURE, UV + vec2(texel.x, -texel.y)) * 0.0625;
	blur += texture(TEXTURE, UV + vec2(-texel.x, 0.0)) * 0.125;
	blur += center * 0.25;
	blur += texture(TEXTURE, UV + vec2(texel.x, 0.0)) * 0.125;
	blur += texture(TEXTURE, UV + vec2(-texel.x, texel.y)) * 0.0625;
	blur += texture(TEXTURE, UV + vec2(0.0, texel.y)) * 0.125;
	blur += texture(TEXTURE, UV + vec2(texel.x, texel.y)) * 0.0625;

	vec4 sharp = center + (center - blur) * strength;
	COLOR = clamp(sharp, 0.0, 1.0);
}
