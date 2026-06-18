shader_type canvas_item;

uniform bool HDR_correction = true;
uniform vec4 WATER_COL : source_color =  vec4(0.176471, 0.635294, 0.85098, 1.0);
uniform vec4 WATER2_COL : source_color =  vec4(0.0588235, 0.529412, 0.776471, 1.0);
uniform vec4 FOAM_COL : source_color = vec4(0.87451, 0.988235, 1, 1.0);

uniform float distortion_speed = 2.0;
uniform vec2 tile = vec2(5.0, 5.0);
uniform vec2 offset = vec2(0, 0);

const float TWOPI = 6.283185307;
const float SIXPI = 18.84955592;


float linearToSRGB(float input) {
    if(input < 0.040449907){
		return input/12.92;
	}else{
		return pow(((input+0.055)/1.055),2.4);
	}
}

vec3 correctHDR(vec3 targetColor) {
	if(HDR_correction){
		vec3 convertedColor = vec3(linearToSRGB(targetColor.r),linearToSRGB(targetColor.g),linearToSRGB(targetColor.b));
	return convertedColor;
	}
	return targetColor;
}

float circ(vec2 pos, vec2 c, float s)
{
    c = abs(pos - c);
    c = min(c, 1.0 - c);

    return smoothstep(0.0, 0.002, sqrt(s) - sqrt(dot(c, c))) * -1.0;
}


float waterlayer(vec2 uv)
{
    // Reduced from 73 to 42 circles by dropping radii < 0.01 — the smaller
    // ones barely contributed visually but each circ() is ~10 GPU ops.
    uv = mod(uv, 1.0);
    float ret = 1.0;
    ret += circ(uv, vec2(0.37378, 0.277169), 0.0268181);
    ret += circ(uv, vec2(0.0317477, 0.540372), 0.0193742);
    ret += circ(uv, vec2(0.430044, 0.882218), 0.0232337);
    ret += circ(uv, vec2(0.641033, 0.695106), 0.0117864);
    ret += circ(uv, vec2(0.0146398, 0.0791346), 0.0299458);
    ret += circ(uv, vec2(0.43871, 0.394445), 0.0289087);
    ret += circ(uv, vec2(0.909446, 0.878141), 0.028466);
    ret += circ(uv, vec2(0.310149, 0.686637), 0.0128496);
    ret += circ(uv, vec2(0.928617, 0.195986), 0.0152041);
    ret += circ(uv, vec2(0.0438506, 0.868153), 0.0268601);
    ret += circ(uv, vec2(0.0449556, 0.953415), 0.023126);
    ret += circ(uv, vec2(0.117761, 0.503309), 0.0151272);
    ret += circ(uv, vec2(0.563517, 0.244991), 0.0292322);
    ret += circ(uv, vec2(0.0489944, 0.200931), 0.0178746);
    ret += circ(uv, vec2(0.569297, 0.624893), 0.0132408);
    ret += circ(uv, vec2(0.298347, 0.710972), 0.0114426);
    ret += circ(uv, vec2(0.119673, 0.541984), 0.0124621);
    ret += circ(uv, vec2(0.629598, 0.295629), 0.0198736);
    ret += circ(uv, vec2(0.334357, 0.266278), 0.0187145);
    ret += circ(uv, vec2(0.918044, 0.968163), 0.0182928);
    ret += circ(uv, vec2(0.71403, 0.576945), 0.0215641);
    ret += circ(uv, vec2(0.748873, 0.413325), 0.0110795);
    ret += circ(uv, vec2(0.0623365, 0.896713), 0.0236203);
    ret += circ(uv, vec2(0.647463, 0.654349), 0.0188713);
    ret += circ(uv, vec2(0.428928, 0.382426), 0.0298806);
    ret += circ(uv, vec2(0.525104, 0.572233), 0.0141796);
    ret += circ(uv, vec2(0.431526, 0.911372), 0.0213234);
    ret += circ(uv, vec2(0.514523, 0.243263), 0.0270685);
    ret += circ(uv, vec2(0.502214, 0.47269), 0.0234534);
    ret += circ(uv, vec2(0.693271, 0.431469), 0.0246533);
    ret += circ(uv, vec2(0.415, 0.884418), 0.0271696);
    ret += circ(uv, vec2(0.0409132, 0.83406), 0.0191398);
    ret += circ(uv, vec2(0.638585, 0.646019), 0.0206129);
    ret += circ(uv, vec2(0.99871, 0.583864), 0.0107329);
    ret += circ(uv, vec2(0.0761895, 0.16327), 0.0145935);
    ret += circ(uv, vec2(0.949386, 0.802936), 0.0100873);
    ret += circ(uv, vec2(0.480122, 0.196554), 0.0110185);
    ret += circ(uv, vec2(0.896854, 0.803707), 0.013969);
    ret += circ(uv, vec2(0.506365, 0.531118), 0.0144016);
    ret += circ(uv, vec2(0.408806, 0.894771), 0.0243923);
    ret += circ(uv, vec2(0.0902811, 0.181775), 0.0108896);
    ret += circ(uv, vec2(0.987324, 0.146545), 0.0288391);
	return max(ret, 0.0);
}

vec3 water(vec2 uv, vec3 cdir, float iTime)
{
    uv *= vec2(0.25);
    // Parallax height distortion with two directional waves at
    // slightly different angles.
    vec2 a = 0.025 * cdir.xz / cdir.y; // Parallax offset
    float h = sin(uv.x + iTime); // Height at UV
    uv += a * h;
    h = sin(0.841471 * uv.x - 0.540302 * uv.y + iTime);
    uv += a * h;

    // Texture distortion
    float d1 = mod(uv.x + uv.y, TWOPI);
    float d2 = mod((uv.x + uv.y + 0.25) * 1.3, SIXPI);
    d1 = iTime * 0.07 + d1;
    d2 = iTime * 0.5 + d2;
    vec2 dist = vec2(
    	sin(d1) * 0.15 + sin(d2) * 0.05,
    	cos(d1) * 0.15 + cos(d2) * 0.05
    );

    vec3 ret = mix(correctHDR(WATER_COL.rgb), correctHDR(WATER2_COL.rgb), waterlayer(uv + dist.xy));
    ret = mix(ret, correctHDR(FOAM_COL.rgb), waterlayer(vec2(1.0) - uv - dist.yx));
    return ret;
}

varying vec2 globalposition;
void vertex(){
	globalposition = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = globalposition / 32.0;
	COLOR.rgb = vec3(water(uv * tile + offset, vec3(0,1,0), TIME * distortion_speed));
}