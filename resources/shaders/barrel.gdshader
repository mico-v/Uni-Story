shader_type canvas_item;

// Barrel distortion — simulates radial lens curvature.
// sigma > 0 bulges outward (fisheye), sigma < 0 pinches inward.
uniform float sigma : hint_range(-0.5, 0.5) = 0.2;
uniform float aspect_ratio : hint_range(0.5, 3.0) = 1.77777778;
uniform float scale : hint_range(0.5, 2.0) = 1.0;
uniform float chroma : hint_range(0.0, 1.0) = 0.0;
uniform float offset : hint_range(-0.5, 0.5) = 0.0;

vec2 convert_uv(vec2 uv, float s) {
	uv -= 0.5;
	uv /= scale;
	float r = sqrt(uv.x * uv.x * aspect_ratio * aspect_ratio + uv.y * uv.y);
	float sin_theta = r * s * 4.0;
	float ratio;
	if (sin_theta < 0.1) {
		ratio = 1.0 + sin_theta * sin_theta / 6.0;
	} else if (sin_theta > 1.0) {
		ratio = 1.5707963 * sin_theta;
	} else {
		ratio = asin(sin_theta) / sin_theta;
	}
	uv *= ratio;
	uv += 0.5;
	return uv;
}

uniform vec4 back_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float s = sigma * 1.0;
	vec4 col;
	if (chroma > 0.0) {
		vec2 cuv_r = convert_uv(UV, s * (1.0 - chroma));
		float r = (cuv_r.x >= 0.0 && cuv_r.x <= 1.0 && cuv_r.y >= 0.0 && cuv_r.y <= 1.0) ? texture(TEXTURE, cuv_r).r : back_color.r;
		vec2 cuv_g = convert_uv(UV, s);
		vec2 ga = (cuv_g.x >= 0.0 && cuv_g.x <= 1.0 && cuv_g.y >= 0.0 && cuv_g.y <= 1.0) ? texture(TEXTURE, cuv_g).ga : back_color.ga;
		vec2 cuv_b = convert_uv(UV, s * (1.0 + chroma));
		float b = (cuv_b.x >= 0.0 && cuv_b.x <= 1.0 && cuv_b.y >= 0.0 && cuv_b.y <= 1.0) ? texture(TEXTURE, cuv_b).b : back_color.b;
		col = vec4(r, ga.x, b, ga.y);
	} else {
		vec2 cuv = convert_uv(UV, s);
		if (cuv.x >= 0.0 && cuv.x <= 1.0 && cuv.y >= 0.0 && cuv.y <= 1.0) {
			col = texture(TEXTURE, cuv);
		} else {
			col = back_color;
		}
	}
	col.rgb += offset * 1.0;
	col.rgb = clamp(col.rgb, 0.0, 1.0);
	COLOR = col;
}
