/*
	Toon glass: a flat see-through tint with hard-edged cartoon glints.

	The glints are drawn in the mesh's own space, one set per lens, so they stay put on the
	lenses as he moves and slide across them a little as his head turns. Both lenses get
	them at the same angle (their UVs are mirrored, so UVs can't be used for this).
*/

shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;

group_uniforms Tint;
/** Lens colour; alpha is how opaque the glass is (0 = clear, 1 = solid). */
uniform vec4 tint : source_color = vec4(0.75, 0.9, 1.0, 0.25);
/** Colour of the darker band across the top of each lens; alpha as above. */
uniform vec4 top_tint : source_color = vec4(0.55, 0.75, 0.95, 0.45);
/** Where the top band starts, from the lens centre (-1 bottom .. 1 top). Above 1 = no band. */
uniform float top_split : hint_range(-1.0, 1.5) = 0.35;

group_uniforms Glints;
uniform vec4 glint_color : source_color = vec4(1.0);
/** Angle of the glint stripes, in degrees (0 = vertical stripes, 45 = diagonal). */
uniform float glint_angle : hint_range(-90.0, 90.0) = 40.0;
/** Position of the main stripe across the lens (-1 .. 1). */
uniform float glint_offset : hint_range(-1.5, 1.5) = -0.25;
uniform float glint_width : hint_range(0.0, 0.5) = 0.14;
/** The thinner stripe beside the main one. Width 0 hides it. */
uniform float glint2_width : hint_range(0.0, 0.5) = 0.05;
uniform float glint2_gap : hint_range(0.0, 1.0) = 0.32;
/** How far the glints slide across the lenses as his head turns. */
uniform float glint_view_shift : hint_range(0.0, 3.0) = 1.2;

group_uniforms Lens_Layout;
/** Centre of the right lens in the mesh's space (the left one mirrors it in x). */
uniform vec2 lens_center = vec2(0.1024, 0.1983);
/** Half the width and height of one lens, in the mesh's space. */
uniform vec2 lens_half_size = vec2(0.0677, 0.0541);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

/** 1 inside a stripe of half-width [param width] around 0, antialiased. */
float stripe(float d, float width) {
	float aa = fwidth(d);
	return 1.0 - smoothstep(width - aa, width + aa, abs(d));
}

void fragment() {
	// position on this lens, -1..1 in each direction
	float side = local_pos.x < 0.0 ? -1.0 : 1.0;
	vec2 p = (local_pos.xy - vec2(side * lens_center.x, lens_center.y)) / lens_half_size;

	// cel-style two-tone tint
	float top = step(top_split, p.y);
	vec4 base = mix(tint, top_tint, top);

	// glints, nudged sideways by where the lens is facing relative to the camera
	float a = radians(glint_angle);
	float d = dot(p, vec2(cos(a), sin(a))) + NORMAL.x * glint_view_shift - glint_offset;
	float glint = stripe(d, glint_width);
	if (glint2_width > 0.0) {
		glint = max(glint, stripe(d - glint2_gap, glint2_width));
	}
	glint *= glint_color.a;

	ALBEDO = mix(base.rgb, glint_color.rgb, glint);
	ALPHA = max(base.a, glint);
}
