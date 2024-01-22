shader_type canvas_item;

uniform float y_offset: hint_range(0.0, 1.0) = 0.0;


void fragment()
{
	vec2 uv = UV - vec2(0.0, y_offset);
	COLOR = texture(TEXTURE, uv);
}
