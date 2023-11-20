shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 text = texture(TEXTURE, UV);
	vec2 centered = UV - 0.5;
	if (length(centered) < 0.1) {
		COLOR = text;
	}
}

void light() {
	// Called for every pixel for every light affecting the CanvasItem.
}
