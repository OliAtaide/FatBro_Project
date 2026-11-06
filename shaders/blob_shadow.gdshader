/*
	A soft round shadow for a flat quad lying on the floor: dark in the middle, fading out to
	nothing at the edge. Grounds a character on a floor that isn't drawn (AR mode).
*/

shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
/** Where the fade starts, as a fraction of the radius (0 = fades all the way from the middle). */
uniform float core : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * (1.0 - smoothstep(core, 1.0, r));
}
