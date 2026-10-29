// Woven fabric for quilt patches. World-space pattern, so the weave runs
// continuously across a patch. Define GHOST before including for the
// see-through placement preview.
#ifdef GHOST
render_mode cull_disabled, blend_mix, depth_draw_opaque;
#else
render_mode cull_disabled;
#endif

uniform vec4 base_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 fleck_color = vec4(1.0);
uniform float weave_scale = 18.0;     // threads per world unit
uniform float weave_strength = 0.12;  // how visible the over/under weave is
uniform float fuzz = 0.0;             // felt-like soft noise
uniform float fleck = 0.0;            // share of tweed flecks (0..1)
uniform float sheen = 0.0;            // silk rim sheen
uniform float rough = 0.9;
uniform float opacity = 1.0;
uniform float wash = 0.0;            // 0 = full colour, 1 = washed-out grey

varying vec3 world_pos;

float bw_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bw_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(bw_hash(i), bw_hash(i + vec2(1.0, 0.0)), u.x),
		mix(bw_hash(i + vec2(0.0, 1.0)), bw_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * weave_scale;
	// Fade fine detail out where it would shimmer (far away / small on screen).
	vec2 fw = fwidth(p);
	float fade = 1.0 - smoothstep(0.35, 0.9, max(fw.x, fw.y));
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float checker = mod(cell.x + cell.y, 2.0);
	float warp = smoothstep(0.0, 0.3, f.y) * smoothstep(1.0, 0.7, f.y);
	float weft = smoothstep(0.0, 0.3, f.x) * smoothstep(1.0, 0.7, f.x);
	float weave = (mix(warp, weft, checker) - 0.5) * weave_strength * fade;
	float n = (bw_noise(world_pos.xz * 34.0) - 0.5) * fuzz * fade
		+ (bw_noise(world_pos.xz * 9.0) - 0.5) * fuzz * 0.6;
	vec3 col = base_color.rgb * (1.0 + weave + n);
	float fl = step(1.0 - fleck, bw_hash(floor(world_pos.xz * 55.0)));
	col = mix(col, fleck_color.rgb, fl * 0.7 * fade);
	col *= COLOR.rgb;  // vertex colour tints merged meshes (white otherwise)
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(grey) * vec3(0.98, 0.97, 0.95), wash);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25 + sheen * 0.4;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base_color.rgb * rim * sheen * 0.5;
#ifdef GHOST
	ALPHA = opacity;
#endif
}
