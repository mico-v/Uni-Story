shader_type canvas_item;

// Barrel Hyper — extreme fisheye with stronger distortion and chromatic aberration.
uniform float sigma : hint_range(0.0, 1.0) = 0.5;
uniform float aspect_ratio : hint_range(0.5, 3.0) = 1.77777778;
uniform float chroma : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec2 uv = UV - 0.5;
	float r = sqrt(uv.x * uv.x * aspect_ratio * aspect_ratio + uv.y * uv.y);
	float sin_theta = r * sigma * 6.0;
	float ratio;
	if (sin_theta < 0.1) {
		ratio = 1.0 + sin_theta * sin_theta / 6.0;
	} else if (sin_theta > 1.0) {
		ratio = 1.5707963 * sin_theta;
	} else {
		ratio = asin(sin_theta) / sin_theta;
	}
	vec2 cuv = uv * ratio + 0.5;

	vec4 col = vec4(0.0);
	col.r = texture(TEXTURE, mix(UV, cuv, chroma * 0.5 + (1.0 - chroma) * 0.35)).r;
	col.g = texture(TEXTURE, mix(UV, cuv, 0.5)).g;
	col.b = texture(TEXTURE, UV + (cuv - UV) * (1.0 + chroma)).b;
	col.a = 1.0;

	col.rgb = clamp(col.rgb, 0.0, 1.0);
	COLOR = col;
}
