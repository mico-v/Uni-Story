shader_type canvas_item;

// Overglow — intense bloom over-exposure effect.
uniform float size : hint_range(0.0, 5.0) = 1.5;
uniform float strength : hint_range(0.0, 5.0) = 2.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 texel = vec2(0.5 / float(textureSize(TEXTURE, 0).x), 0.0);

	float blur = size;
	vec3 glow = texture(TEXTURE, UV).rgb * 0.227027;
	glow += texture(TEXTURE, UV + texel * blur * 1.0).rgb * 0.1945946;
	glow += texture(TEXTURE, UV - texel * blur * 1.0).rgb * 0.1945946;
	glow += texture(TEXTURE, UV + texel * blur * 2.0).rgb * 0.1216216;
	glow += texture(TEXTURE, UV - texel * blur * 2.0).rgb * 0.1216216;
	glow += texture(TEXTURE, UV + texel * blur * 3.0).rgb * 0.054054;
	glow += texture(TEXTURE, UV - texel * blur * 3.0).rgb * 0.054054;
	glow += texture(TEXTURE, UV + texel * blur * 4.0).rgb * 0.016216;
	glow += texture(TEXTURE, UV - texel * blur * 4.0).rgb * 0.016216;

	// Threshold — only bright areas glow
	glow = max(glow - threshold, 0.0) / (1.0 - threshold);

	glow *= glow;
	glow *= glow;
	glow *= strength;
	glow = clamp(glow, 0.0, 1.0);

	col.rgb = col.rgb + glow;
	col.rgb = clamp(col.rgb, 0.0, 1.0);
	COLOR = col;
}
