shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.3;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));
	
	float tl = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-texel.x, texel.y)).rgb, vec3(0.333));
	float t  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, texel.y)).rgb, vec3(0.333));
	float tr = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(texel.x, texel.y)).rgb, vec3(0.333));
	float l  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-texel.x, 0.0)).rgb, vec3(0.333));
	float r  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(texel.x, 0.0)).rgb, vec3(0.333));
	float bl = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-texel.x, -texel.y)).rgb, vec3(0.333));
	float b  = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, -texel.y)).rgb, vec3(0.333));
	float br = dot(texture(SCREEN_TEXTURE, SCREEN_UV + vec2(texel.x, -texel.y)).rgb, vec3(0.333));
	
	float h = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	float v = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	
	float edge = sqrt(h * h + v * v);
	vec4 original = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	if (edge > threshold) {
		COLOR = mix(original, edge_color, amount);
	} else {
		COLOR = mix(original, vec4(0.0, 0.0, 0.0, 0.0), amount * 0.5);
	}
}
