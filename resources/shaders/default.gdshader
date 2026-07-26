shader_type canvas_item;

// Default — identity pass-through shader. Used as a fallback or base template.
void fragment() {
	COLOR = texture(TEXTURE, UV);
}
