shader_type canvas_item;

// Recolors a sprite toward a solid target colour while preserving its shape
// (alpha) and internal shading (via luminance). Tween `mix_amount` 0 -> 1 to
// fade from the original texture to the recoloured silhouette. Used by the
// brain-screen final-boss reward animation (see brain_reward.gd).
// Mirrors resources/shaders/grayscale.gdshader.

uniform vec4 target_color : source_color = vec4(0.416, 0.176, 0.486, 1.0);
uniform float mix_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 recolored = target_color.rgb * (lum * 0.6 + 0.4);
	COLOR = vec4(mix(tex.rgb, recolored, mix_amount), tex.a);
}
