shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.3;
uniform float samples : hint_range(4.0, 32.0) = 10.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);
	
	vec4 color = vec4(0.0);
	float total = 0.0;
	for (int i = 0; i < 32; i++) {
		if (float(i) >= samples) break;
		float t = float(i) / max(samples - 1.0, 1.0);
		vec2 zoom_uv = mix(uv, center, t * amount);
		color += texture(SCREEN_TEXTURE, zoom_uv);
		total += 1.0;
	}
	COLOR = color / total;
}
