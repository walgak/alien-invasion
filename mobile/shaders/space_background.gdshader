shader_type canvas_item;
render_mode unshaded;

uniform vec2 arena_size = vec2(540.0, 960.0);
uniform float visual_time = 0.0;

varying vec2 canvas_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

float cloud_noise(vec2 p) {
	float value = 0.0;
	float amplitude = 0.53;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * noise(p);
		p = mat2(vec2(1.60, 1.20), vec2(-1.20, 1.60)) * p + vec2(8.3, 2.7);
		amplitude *= 0.48;
	}
	return value;
}

vec3 star_layer(vec2 p, float spacing, float seed) {
	vec2 grid = p / spacing;
	vec2 cell = floor(grid);
	float chance = hash21(cell + seed);
	vec2 offset = vec2(hash21(cell + seed + 9.1), hash21(cell + seed + 38.4));
	// Keep each star inside its tile, including its halo, so there are no seams.
	vec2 delta = (fract(grid) - mix(vec2(0.16), vec2(0.84), offset)) * spacing;
	float size = mix(0.45, 1.15, chance);
	float distance_squared = dot(delta, delta);
	float core = exp(-distance_squared / (size * size));
	float halo = exp(-distance_squared / (size * size * 13.0)) * 0.12;
	float twinkle = 0.80 + 0.20 * sin(visual_time * (0.50 + chance) + chance * 73.0);
	vec3 tint = mix(vec3(0.37, 0.65, 0.97), vec3(0.94, 0.87, 0.71), offset.x);
	return tint * (core + halo) * twinkle * step(0.42, chance);
}

void vertex() {
	canvas_position = VERTEX;
}

void fragment() {
	vec2 p = canvas_position;
	vec2 uv = p / max(arena_size, vec2(1.0));
	vec2 sky = p / 410.0;
	float broad = cloud_noise(sky * 1.3 + vec2(6.2, 3.8));
	float cloud = cloud_noise(sky * 4.2 + vec2(broad * 2.5, broad * -1.8));
	float band_distance = (uv.x - 0.73 + 0.40 * sin(uv.y * 4.0 + 0.5)) * 1.75;
	float band = exp(-band_distance * band_distance);
	float filaments = smoothstep(0.34, 0.83, cloud) * band;
	vec3 color = mix(vec3(0.007, 0.013, 0.032), vec3(0.013, 0.027, 0.061), broad);
	vec3 nebula_tint = mix(vec3(0.047, 0.058, 0.155), vec3(0.021, 0.127, 0.166), broad);
	color += nebula_tint * filaments * 0.78;
	color += vec3(0.030, 0.026, 0.061) * pow(cloud, 4.0) * band;
	color += star_layer(p + vec2(0.0, visual_time * 0.65), 62.0, 11.7) * 0.72;
	color += star_layer(p + vec2(19.0, visual_time * 1.15), 141.0, 82.1) * 0.87;

	// A spherical planet supplies curved surface detail and a lit horizon for
	// the refraction pass. Its low contrast leaves bullets and ships readable.
	vec2 planet = (p - arena_size * vec2(0.73, 0.40)) / 178.0;
	float radius = length(planet);
	float atmosphere = exp(-abs(radius - 1.01) * 43.0);
	vec3 light_direction = normalize(vec3(-0.69, -0.48, 0.38));
	vec3 normal = vec3(planet, sqrt(max(0.0, 1.0 - dot(planet, planet))));
	float sunlight = max(0.0, dot(normal, light_direction));
	float hemisphere_light = 0.19 + 0.81 * max(0.0, dot(normalize(vec3(planet, 0.17)), light_direction));
	color += vec3(0.075, 0.25, 0.35) * atmosphere * hemisphere_light * 0.70;
	if (radius < 1.0) {
		vec2 surface = vec2(atan(normal.x, max(normal.z, 0.001)), asin(clamp(normal.y, -1.0, 1.0)));
		float land = cloud_noise(surface * 5.2 + vec2(11.3, 21.8));
		float wisps = noise(surface * vec2(16.0, 33.0) + land * 3.0);
		vec3 planet_color = mix(vec3(0.013, 0.043, 0.069), vec3(0.061, 0.107, 0.127), smoothstep(0.40, 0.65, land));
		planet_color += vec3(0.060, 0.098, 0.115) * smoothstep(0.51, 0.73, wisps) * 0.44;
		planet_color *= 0.10 + sunlight * 0.95;
		planet_color += vec3(0.028, 0.116, 0.170) * pow(1.0 - normal.z, 3.0) * sunlight;
		float silhouette = 1.0 - smoothstep(0.992, 1.0, radius);
		color = mix(color, planet_color, silhouette);
	}
	float vignette = 1.0 - 0.30 * smoothstep(0.2, 0.83, length(uv - vec2(0.5)));
	COLOR = vec4(color * vignette, 1.0);
}
