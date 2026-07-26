shader_type canvas_item;

// Masked Mosaic — mosaic effect within a circular or rectangular mask region.
uniform float tile_size : hint_range(2.0, 64.0) = 8.0;
uniform float mask_x : hint_range(0.0, 1.0) = 0.5;
uniform float mask_y : hint_range(0.0, 1.0) = 0.5;
uniform float mask_radius : hint_range(0.0, 1.0) = 0.3;
uniform float mask_softness : hint_range(0.0, 0.5) = 0.05;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 pixel_uv = floor(UV * tile_size) / tile_size;
	vec4 mosaic = texture(TEXTURE, pixel_uv);

	float dist = distance(UV, vec2(mask_x, mask_y));
	float mask = 1.0 - smoothstep(mask_radius - mask_softness, mask_radius + mask_softness, dist);

	COLOR = mix(base, mosaic, mask);
}
