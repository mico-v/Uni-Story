shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 delta = uv - center;
	float dist = length(delta);

	if (amount < 0.01) {
		COLOR = texture(SCREEN_TEXTURE, uv);
	} else {
		vec4 col = vec4(0.0);
		float total = 0.0;
		for (int i = 0; i < 4; i++) {
			float t = float(i) * 0.25;
			float s = 1.0 + amount * t;
			vec2 offset_uv = delta * s + center;
			float w = 1.0 - t;
			col += texture(SCREEN_TEXTURE, offset_uv) * w;
			total += w;
		}
		COLOR = col / max(total, 0.01);
	}
}
