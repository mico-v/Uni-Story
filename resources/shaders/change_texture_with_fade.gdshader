shader_type canvas_item;

// Change Texture With Fade — crossfade between current texture and a second texture.
uniform sampler2D next_tex : hint_default_white;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 current = texture(TEXTURE, UV);
	vec4 next = texture(next_tex, UV);
	COLOR = mix(current, next, progress);
}
