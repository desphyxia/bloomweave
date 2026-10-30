// Satin-stitch embroidery for bloom petals and leaves: fine parallel
// thread lines with a soft sheen. Define GHOST for the see-through preview.
#ifdef GHOST
render_mode cull_disabled, blend_mix, depth_draw_opaque;
#else
render_mode cull_disabled;
#endif

uniform vec4 color = vec4(1.0);
uniform float lines = 90.0;
uniform float opacity = 1.0;

void fragment() {
	float s = 0.86 + 0.14 * sin(UV.x * lines);
	ALBEDO = color.rgb * COLOR.rgb * s;  // vertex colour tints merged meshes
	ROUGHNESS = 0.45;
	SPECULAR = 0.55;
#ifdef GHOST
	ALPHA = opacity;
#endif
}
