shader_type canvas_item;

// Color — HSV-based color adjustment (hue shift, saturation, value/brightness).
uniform float hue : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation : hint_range(-1.0, 1.0) = 0.0;
uniform float value : hint_range(-1.0, 1.0) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(col.rgb);
	hsv.x = fract(hsv.x + hue);
	hsv.y = clamp(hsv.y + saturation, 0.0, 1.0);
	hsv.z = clamp(hsv.z + value, 0.0, 1.0);
	col.rgb = hsv_to_rgb(hsv);
	COLOR = col;
}
