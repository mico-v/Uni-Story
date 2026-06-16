shader_type canvas_item;

// Grayscale effect — amount = 0 → original color, amount = 1 → full grayscale.
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float luminance = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(luminance), amount), c.a);
}
