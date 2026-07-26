shader_type canvas_item;
// Post variant: samples SCREEN_TEXTURE

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = 1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));

	float tl = dot(texture(SCREEN_TEXTURE, uv + vec2(-texel.x, texel.y)).rgb, vec3(0.299, 0.587, 0.114));
	float t  = dot(texture(SCREEN_TEXTURE, uv + vec2(0.0, texel.y)).rgb, vec3(0.299, 0.587, 0.114));
	float tr = dot(texture(SCREEN_TEXTURE, uv + vec2(texel.x, texel.y)).rgb, vec3(0.299, 0.587, 0.114));
	float l  = dot(texture(SCREEN_TEXTURE, uv + vec2(-texel.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float r  = dot(texture(SCREEN_TEXTURE, uv + vec2(texel.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float bl = dot(texture(SCREEN_TEXTURE, uv + vec2(-texel.x, -texel.y)).rgb, vec3(0.299, 0.587, 0.114));
	float b  = dot(texture(SCREEN_TEXTURE, uv + vec2(0.0, -texel.y)).rgb, vec3(0.299, 0.587, 0.114));
	float br = dot(texture(SCREEN_TEXTURE, uv + vec2(texel.x, -texel.y)).rgb, vec3(0.299, 0.587, 0.114));

	float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
	float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
	float edge = sqrt(gx*gx + gy*gy);

	vec4 col = texture(SCREEN_TEXTURE, uv);
	float e = step(threshold, edge);
	col.rgb = mix(col.rgb, vec3(e), amount);
	COLOR = col;
}
