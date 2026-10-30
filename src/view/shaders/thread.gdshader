// Twisted embroidery thread for seam stitches and corridor trails.
// UV.x runs along the thread, UV.y around it.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float twist = 28.0;

void fragment() {
	float s = sin(UV.x * twist + UV.y * 6.2831853 * 2.0);
	float strand = 0.78 + 0.22 * smoothstep(-0.7, 0.7, s);
	ALBEDO = color.rgb * COLOR.rgb * strand;  // vertex colour tints merged meshes
	ROUGHNESS = 0.6;
	SPECULAR = 0.45;
}
