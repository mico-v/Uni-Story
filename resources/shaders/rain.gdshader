shader_type canvas_item;

// Rain — animated rain drops with trails and static droplets.
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float aspect_ratio : hint_range(0.5, 3.0) = 1.77777778;
uniform float speed : hint_range(0.1, 3.0) = 1.0;

float saw(float a, float b, float t) {
	t = clamp((t - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

float random2d(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec3 random3d(vec3 st) {
	return vec3(
		fract(sin(dot(st, vec3(12.9898, 78.233, 45.5432))) * 43758.5453123),
		fract(sin(dot(st, vec3(39.346, 12.459, 83.123))) * 43758.5453123),
		fract(sin(dot(st, vec3(73.156, 29.755, 17.119))) * 43758.5453123)
	);
}

float static_drops(vec2 uv, float t) {
	vec3 n = random3d(vec3(floor(uv), 0.0));
	float d = length(fract(uv) - n.xy);
	float fade = saw(0.5, 0.0, fract(t + n.z));
	float c = saw(0.3, 0.0, d) * fract(n.z * 1000.0) * fade;
	return c;
}

vec2 drop_layer(vec2 uv, float t) {
	vec2 grid = vec2(12.0, 2.0);
	float col_shift = random2d(vec2(floor(uv.x * grid.x), 0.0));
	float y_offset = t * speed + col_shift;
	vec2 uv_grid = uv * grid + vec2(0.0, y_offset);
	vec3 n = random3d(vec3(floor(uv_grid), 0.0));
	vec2 st = fract(uv_grid) - vec2(0.5, 0.0);
	float x = n.x - 0.5;
	float wiggle = uv.y * 20.0;
	wiggle = sin(wiggle + sin(wiggle));
	x += wiggle * (0.5 - abs(x)) * (n.y - 0.5);
	x *= 0.7;
	float y = saw(0.8, 0.0, fract(t + n.z));
	float d = length((st - vec2(x, y)) * grid.yx);
	float main_drop = saw(0.4, 0.0, d);
	float r = saw(1.0, 0.0, st.y);
	float trail = saw(0.2, 0.0, abs(st.x - x));
	float trail_front = saw(-0.02, 0.02, st.y - y);
	trail *= trail_front * r;
	y = fract(uv.y * 10.0) + (st.y - 0.5);
	float dd = length(st - vec2(x, y));
	float droplets = saw(0.3, 0.0, dd);
	float c = main_drop + trail_front * droplets * r;
	return vec2(c, trail);
}

vec2 drops(vec2 uv, float t, float l0, float l1, float l2) {
	float s = static_drops(uv * 40.0, t) * l0;
	vec2 m1 = drop_layer(uv * 0.5, t) * l1;
	vec2 m2 = drop_layer(uv, t) * l2;
	float c = s + m1.x + m2.x;
	c = clamp(c, 0.0, 1.0);
	float trail = m1.y + m2.y;
	return vec2(c, trail);
}

void fragment() {
	vec2 uv = UV * vec2(aspect_ratio, 1.0);
	float t = TIME * 0.2 * speed;

	float l0 = strength * 2.0;
	float l1 = saw(0.25, 0.75, strength);
	float l2 = saw(0.0, 0.5, strength);

	vec2 c = drops(uv, t, l0, l1, l2);
	vec2 e = vec2(0.001, 0.0);
	float cx = drops(uv + e, t, l0, l1, l2).x;
	float cy = drops(uv + e.yx, t, l0, l1, l2).x;
	vec2 n = vec2(cx - c.x, cy - c.x);

	vec4 col = texture(TEXTURE, UV + n * 0.5);
	vec2 texel = vec2(0.5 / max(float(textureSize(TEXTURE, 0).x), 1.0), 0.0);
	vec3 blur = texture(TEXTURE, UV).rgb * 0.227027;
	blur += texture(TEXTURE, UV + texel * 3.0).rgb * 0.1945946;
	blur += texture(TEXTURE, UV - texel * 3.0).rgb * 0.1945946;
	blur += texture(TEXTURE, UV + texel * 6.0).rgb * 0.1216216;
	blur += texture(TEXTURE, UV - texel * 6.0).rgb * 0.1216216;
	blur += texture(TEXTURE, UV + texel * 9.0).rgb * 0.054054;
	blur += texture(TEXTURE, UV - texel * 9.0).rgb * 0.054054;
	vec4 col2 = vec4(blur, 1.0);

	col = mix(col2, col, clamp(c.x + c.y, 0.0, 1.0));
	COLOR = col;
}
