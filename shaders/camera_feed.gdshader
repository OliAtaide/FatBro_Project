/*
	Draws a phone camera feed full-screen, rotated upright and cropped to fill the screen
	without stretching. Handles RGB feeds and YCbCr ones (packed, or split into Y and CbCr).
	Driven by ArView, which fills in the uniforms.
*/

shader_type canvas_item;

/** The RGB image; the YCbCr one (mode 1); or the Y (brightness) one (mode 2). */
uniform sampler2D feed_main : filter_linear;
/** The CbCr (colour) image, for mode 2. */
uniform sampler2D feed_cbcr : filter_linear;
/** 0 = RGB, 1 = YCbCr in one image, 2 = Y and CbCr in separate images. */
uniform int mode = 0;
/** Screen UV -> image UV: rotation, crop and the feed's own transform, all in one. */
uniform vec2 uv_x = vec2(1.0, 0.0);
uniform vec2 uv_y = vec2(0.0, 1.0);
uniform vec2 uv_origin = vec2(0.0);

void fragment() {
	vec2 uv = uv_x * SCREEN_UV.x + uv_y * SCREEN_UV.y + uv_origin;
	if (mode != 0) {
		// BT.709, the same conversion Godot uses for camera backgrounds
		vec3 ycbcr = mode == 2
				? vec3(texture(feed_main, uv).r, texture(feed_cbcr, uv).rg - vec2(0.5))
				: texture(feed_main, uv).rgb - vec3(0.0, 0.5, 0.5);
		COLOR = vec4(mat3(
				vec3(1.0, 1.0, 1.0),
				vec3(0.0, -0.18732, 1.8556),
				vec3(1.57481, -0.46813, 0.0)) * ycbcr, 1.0);
	} else {
		COLOR = vec4(texture(feed_main, uv).rgb, 1.0);
	}
}
