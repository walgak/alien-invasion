shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 arena_size = vec2(540.0, 960.0);
uniform int lens_count = 0;
uniform vec4 lenses[8]; // center, influence radius, strength
uniform vec4 lens_styles[8]; // core radius, direction, object flag, simulation time
uniform int strand_count = 0;
uniform vec4 strands[6]; // boss/tail endpoint, rock/cannon endpoint
uniform vec4 strand_styles[6]; // width, strength, simulation time, travel direction
uniform float refraction_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 pixel = UV * arena_size;
	vec2 displacement = vec2(0.0);
	vec3 gleam = vec3(0.0);
	float shade = 0.0;
	float dispersion = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= lens_count) { break; }
		vec4 lens = lenses[i];
		vec4 style = lens_styles[i];
		vec2 delta = pixel - lens.xy;
		// A tilted circular well reads as an elliptical surface with depth.
		float flatten = mix(0.83, 1.0, style.z);
		vec2 surface = delta / vec2(1.0, flatten);
		float radius = length(surface);
		if (radius >= lens.z || radius < 0.5) { continue; }
		vec2 normal = surface / radius;
		float shell = max(radius - style.x, 0.0);
		float envelope = (1.0 - smoothstep(lens.z * 0.66, lens.z, radius)) * smoothstep(style.x * 0.65, style.x + 9.0, radius);
		float phase = shell * 0.255 - style.w * style.y * 5.5;
		float wave = sin(phase);
		float ripple = wave * envelope;
		float throat = exp(-shell * shell / (style.z > 0.5 ? 620.0 : 1750.0));
		float bend = (ripple * mix(9.0, 3.0, style.z) + throat * mix(27.0, 15.0, style.z) * -style.y) * lens.w;
		vec2 tangent = vec2(-normal.y, normal.x);
		displacement += (normal * bend + tangent * throat * (1.0 - style.z) * 6.0 * lens.w) * vec2(1.0, flatten);
		// Opposing light and shadow on each fold give its refracted ridge thickness.
		float crest = pow(max(0.0, cos(phase)), 12.0) * envelope;
		float trough = pow(max(0.0, -cos(phase + 0.55)), 6.0) * envelope;
		float rim_distance = (radius - style.x - 6.0) / 5.0;
		float rim = exp(-rim_distance * rim_distance);
		float lighting = 0.4 + 0.6 * max(dot(normal, normalize(vec2(-0.5, -0.8))), 0.0);
		vec3 tint = style.y < 0.0 && style.z < 0.5 ? vec3(0.52, 0.40, 1.0) : vec3(0.40, 0.84, 1.0);
		gleam += tint * (crest * 0.105 * lighting + rim * 0.2) * lens.w;
		shade += (trough * 0.2 + throat * 0.15) * lens.w;
		dispersion += (crest + rim) * 0.65 * lens.w;
	}
	for (int i = 0; i < 6; i++) {
		if (i >= strand_count) { break; }
		vec4 strand = strands[i];
		vec4 style = strand_styles[i];
		vec2 axis = strand.zw - strand.xy;
		float length_squared = max(dot(axis, axis), 1.0);
		float along = clamp(dot(pixel - strand.xy, axis) / length_squared, 0.0, 1.0);
		vec2 tangent = axis * inversesqrt(length_squared);
		vec2 normal = vec2(-tangent.y, tangent.x);
		float bend = sin(along * TAU * 2.0 + style.z * 4.0) * 3.0 * sin(along * 3.14159265);
		vec2 nearest = strand.xy + axis * along + normal * bend;
		vec2 delta = pixel - nearest;
		float distance_to_strand = length(delta);
		if (distance_to_strand > style.x * 2.8) { continue; }
		float cross_section = dot(delta, normal) / style.x;
		float envelope = exp(-distance_to_strand * distance_to_strand / (style.x * style.x));
		float travel = sin(along * 24.0 - style.z * style.w * 12.0);
		// A cylindrical lens stretches the sky across the strand, with travelling folds.
		displacement += normal * cross_section * envelope * 22.0 * style.y;
		displacement += tangent * travel * envelope * 5.0 * style.y;
		float highlight_distance = (cross_section + 0.38) * 3.8;
		float shadow_distance = (cross_section - 0.5) * 2.8;
		float highlight = exp(-highlight_distance * highlight_distance);
		float shadow = exp(-shadow_distance * shadow_distance);
		float ends = smoothstep(0.0, 0.06, along) * (1.0 - smoothstep(0.94, 1.0, along));
		gleam += vec3(0.33, 0.70, 0.9) * highlight * envelope * ends * style.y * 0.085;
		shade += shadow * envelope * ends * style.y * 0.22;
		dispersion += envelope * style.y * 0.3;
	}
	// Keep sampling inside the copied viewport, including folds beside an edge.
	vec2 half_pixel = SCREEN_PIXEL_SIZE * 0.5;
	vec2 warped_uv = clamp(SCREEN_UV + displacement / arena_size * refraction_strength, half_pixel, vec2(1.0) - half_pixel);
	vec2 fringe = normalize(displacement + vec2(0.001)) * min(dispersion, 1.0) / arena_size * refraction_strength;
	vec3 sky = texture(screen_texture, warped_uv).rgb;
	sky.r = texture(screen_texture, clamp(warped_uv + fringe, half_pixel, vec2(1.0) - half_pixel)).r;
	sky.b = texture(screen_texture, clamp(warped_uv - fringe, half_pixel, vec2(1.0) - half_pixel)).b;
	COLOR = vec4(sky * (1.0 - min(shade, 0.5)) + gleam, 1.0);
}
