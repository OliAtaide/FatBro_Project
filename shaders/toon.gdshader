/*
	Toon Shader by Firerabbit
	
	MIT License
*/

shader_type spatial;
render_mode cull_disabled, blend_mix;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D tex : source_color, hint_default_white;

uniform sampler2D normal_map : hint_normal;
uniform float normal_strength : hint_range(-16.0, 16.0) = 1.0;

uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_width : hint_range(0.0, 0.5) = 0.001;
uniform vec4 shadow_color: source_color = vec4(0.705);

uniform float _specular_smoothness : hint_range(0.0,0.5) = 0.01;
uniform float _specular_strength : hint_range(0.0,0.25) = 0.075;
uniform float _glossiness : hint_range(0.01,0.5) = 0.1;

uniform float _rim_size : hint_range(0,1) = 0.5;
uniform float _rim_smoothness : hint_range(0.0,0.5) = 0.01;

// recolouring: tint_color multiplies the texture where tint_mask is white (his shirt)
uniform sampler2D tint_mask : hint_default_black, filter_linear;
uniform vec4 tint_color : source_color = vec4(1.0);

// a decal (a costume's shirt print) laid over the texture, inside print_rect
// (xy: its top-left corner in UV, zw: its size; zero size means no print)
uniform sampler2D print_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform vec4 print_rect = vec4(0.0);

void fragment() {
	ALBEDO = texture(tex, UV).rgb * color.rgb;
	ALBEDO = mix(ALBEDO, ALBEDO * tint_color.rgb, texture(tint_mask, UV).r);

	// sampled everywhere (mipmaps need it out of any branch), then masked to the rect
	vec2 print_uv = (UV - print_rect.xy) / max(print_rect.zw, vec2(1e-5));
	vec4 print_color = texture(print_tex, print_uv);
	bool in_rect = all(greaterThanEqual(print_uv, vec2(0.0))) && all(lessThanEqual(print_uv, vec2(1.0)));
	if (print_rect.z > 0.0 && in_rect) {
		ALBEDO = mix(ALBEDO, print_color.rgb * color.rgb, print_color.a);
	}

	// unassigned normal_map defaults to a flat normal, so this is a no-op without one
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}

// Called once per light. Every term is scaled by that light's color/energy and
// distance/shadow attenuation, so many lights add up the same way they do on
// standard materials. ALBEDO is applied by the engine afterwards.
void light() {
	// toon band: 0 on the shadow side, 1 on the lit side
	// (width kept above 0: smoothstep with equal edges is undefined, and some GPUs show it)
	float width = max(shadow_width, 0.001);
	float band = smoothstep(shadow - width, shadow + width, dot(NORMAL, LIGHT));
	vec3 light_amount = LIGHT_COLOR * ATTENUATION / PI;

	// diffuse: shadow side keeps a fraction of the light instead of going black
	DIFFUSE_LIGHT += mix(shadow_color.rgb, vec3(1.0), band) * light_amount;

	// specular
	vec3 H = normalize(VIEW + LIGHT);
	float NdotH = max(0.0, dot(NORMAL, H));
	float specular_intensity = pow(NdotH, 1.0 / _glossiness);
	float specular = smoothstep(0.5 - _specular_smoothness, 0.5 + _specular_smoothness, specular_intensity);

	// rim
	float rimDot = 1.0 - dot(VIEW, NORMAL);
	float rim = smoothstep(1.0 - _rim_size - _rim_smoothness, 1.0 - _rim_size + _rim_smoothness, rimDot * band);

	SPECULAR_LIGHT += (specular + rim) * _specular_strength * band * light_amount;
}