shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Procedural glowing grid floor. No textures — lines are derived from world-space
// coordinates with a screen-space-consistent width via fwidth, fading with distance.

uniform vec3 line_color : source_color = vec3(0.12, 0.45, 0.55);
uniform vec3 bg_color : source_color = vec3(0.015, 0.025, 0.045);
uniform vec3 major_color : source_color = vec3(0.20, 0.65, 0.75);
uniform float cell_size = 2.0;
uniform float major_every = 3.0;
uniform float fade_dist = 26.0;
uniform float emission_strength = 0.8;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 coord) {
	vec2 g = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	vec2 minor = world_pos.xz / cell_size;
	vec2 major = world_pos.xz / (cell_size * major_every);

	float minor_i = grid_line(minor);
	float major_i = grid_line(major);

	float d = length(world_pos.xz);
	float fade = clamp(1.0 - d / fade_dist, 0.0, 1.0);
	fade = fade * fade;

	vec3 col = bg_color;
	col = mix(col, line_color, minor_i * fade);
	col = mix(col, major_color, major_i * fade);

	ALBEDO = col;
	EMISSION = (line_color * minor_i + major_color * major_i) * fade * emission_strength;
}
