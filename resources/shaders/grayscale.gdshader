shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(gray, gray, gray, tex.a);
}
