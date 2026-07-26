shader_type canvas_item;

// Overlay — blend a texture (screen/window/mask) over the base image.
uniform sampler2D overlay_tex : hint_default_white;
uniform float blend : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 over = texture(overlay_tex, UV);
	over.rgb *= tint.rgb;
	over.a *= tint.a;
	vec3 blended = mix(base.rgb, over.rgb * over.a + base.rgb * (1.0 - over.a), blend);
	COLOR = vec4(blended, base.a);
}
