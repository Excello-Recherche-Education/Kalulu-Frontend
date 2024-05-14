shader_type canvas_item;

uniform sampler2D dissolve_texture;
uniform vec4 burn_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float burn_size = 0.1;
uniform float dissolve_amount : hint_range(0, 1) = 0.0;
uniform float emission_amount = 1.0;


void fragment() {
	vec4 out_color = texture(TEXTURE, UV);

	float dissolve = dissolve_amount * (1.0 + 2.0 * burn_size) - burn_size;

	float sample = texture(dissolve_texture, UV).r;
	float emission_value = 1.0 - smoothstep(dissolve, dissolve + burn_size, sample);
	vec3 emission = burn_color.rgb * emission_value * emission_amount;

	COLOR = vec4(max(out_color.rgb, emission), smoothstep(dissolve - burn_size, dissolve, sample) * out_color.a);
	COLOR.rgb = clamp(COLOR.rgb / COLOR.a, vec3(0.0), vec3(1.0));
}
