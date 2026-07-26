shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);
	float blur = amount * dist * 0.05;
	vec2 delta = normalize(uv - center) * blur;

	if (amount < 0.01) {
		COLOR = texture(SCREEN_TEXTURE, uv);
	} else {
		vec4 col = vec4(0.0);
		float total = 0.0;
		for (int i = 0; i < 4; i++) {
			float t = float(i) * 0.25;
			float w = 1.0 - t;
			col += texture(SCREEN_TEXTURE, uv + delta * t) * w;
			total += w;
		}
		COLOR = col / max(total, 0.01);
	}
}
