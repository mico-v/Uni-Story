shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float samples : hint_range(4.0, 32.0) = 10.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);
	vec2 dir = uv - center;
	
	vec4 color = vec4(0.0);
	float total = 0.0;
	for (int i = 0; i < 32; i++) {
		if (float(i) >= samples) break;
		float t = float(i) / max(samples - 1.0, 1.0);
		color += texture(SCREEN_TEXTURE, uv + dir * t * amount * 0.1);
		total += 1.0;
	}
	COLOR = color / total;
}
