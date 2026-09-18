shader_type canvas_item;
// Opaque background layer. This runs per pixel, before ships and the refraction pass.
// Coordinates are logical viewport pixels; visual_time is frozen by the pause menu.
render_mode unshaded;

uniform vec2 arena_size = vec2(540.0, 960.0);
uniform float visual_time = 0.0;
uniform vec3 sector_light = vec3(-0.4, -0.3, 0.8);
uniform float light_period = 0.0;
uniform vec2 camera_jitter = vec2(0.0);

varying vec2 canvas_position;

float hash21(vec2 p) {
	// Stable pseudo-random value: the same cell or planet ID always produces the same art.
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	// Interpolate four hashed grid corners to avoid hard square boundaries.
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

float cloud_noise(vec2 p) {
	// Four rotated noise octaves add large clouds and progressively finer surface detail.
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
	// One candidate star per grid cell, with separate halo, size, tint and twinkle.
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
	// Preserve logical pixel coordinates for the fragment shader.
	canvas_position = VERTEX;
}

void fragment() {
	// Composite nebula, scrolling star layers, one passing planet, then the vignette.
	vec2 p = canvas_position + camera_jitter;
	vec2 uv = p / max(arena_size, vec2(1.0));
	vec2 sky = (p - vec2(0.0, visual_time * 5.0)) / 410.0;
	float broad = cloud_noise(sky * 1.3 + vec2(6.2, 3.8));
	float cloud = cloud_noise(sky * 4.2 + vec2(broad * 2.5, broad * -1.8));
	float band_distance = (uv.x - 0.73 + 0.40 * sin(uv.y * 4.0 + 0.5)) * 1.75;
	float band = exp(-band_distance * band_distance);
	// Keep the void dark while making dense clouds richly coloured. These masks
	// reuse the existing two noise fields, so colour depth adds no noise octaves.
	float filaments = smoothstep(0.32, 0.79, cloud) * band;
	float cloud_edges = smoothstep(0.43, 0.72, cloud) * band;
	vec3 color = mix(vec3(0.006, 0.011, 0.029), vec3(0.012, 0.025, 0.057), broad);
	float colour_region = smoothstep(0.16, 0.84, 0.5 + 0.5 * sin(sky.y * 0.78 + sky.x * 0.50 + broad * 4.0));
	vec3 cool_cloud = mix(vec3(0.12, 0.075, 0.56), vec3(0.025, 0.43, 0.55), colour_region);
	float magenta_region = smoothstep(0.32, 0.91, 0.5 + 0.5 * sin(sky.x * 1.20 - sky.y * 0.52 + broad * 5.4));
	vec3 nebula_tint = mix(cool_cloud, vec3(0.58, 0.045, 0.36), magenta_region * 0.86);
	color += nebula_tint * filaments * 1.24;
	// Narrow luminous wisps suggest lit gas, without whitening the entire sky.
	vec3 wisp_tint = mix(vec3(0.10, 0.30, 0.55), vec3(0.38, 0.10, 0.42), magenta_region);
	color += wisp_tint * cloud_edges * pow(cloud, 3.0) * 0.80;
	color += star_layer(p - vec2(0.0, visual_time * 20.0), 62.0, 11.7) * 0.72;
	color += star_layer(p - vec2(19.0, visual_time * 42.0), 141.0, 82.1) * 0.87;

	// A spherical planet supplies curved surface detail and a lit horizon for
	// the refraction pass. Its low contrast leaves bullets and ships readable.
	float travel_span = arena_size.y + 2200.0;
	float travel = visual_time * 22.0 + arena_size.y * 0.40 + 300.0;
	float planet_id = floor(travel / travel_span);
	float variation = hash21(vec2(planet_id, 37.0));
	vec2 planet_center = vec2(arena_size.x * mix(0.22, 0.78, variation), mod(travel, travel_span) - 300.0);
	vec2 planet = (p - planet_center) / mix(65.0, 235.0, hash21(vec2(planet_id, 71.0)));
	float radius = length(planet);
	// Composite the far half before the sphere and the near half afterwards.
	// The signed tilted ring coordinate provides the depth ordering at each pixel.
	float ring_angle = mix(-0.65, 0.65, hash21(vec2(planet_id, 19.0)));
	vec2 ring = mat2(vec2(cos(ring_angle),sin(ring_angle)),vec2(-sin(ring_angle),cos(ring_angle))) * planet;
	float ring_r = length(ring * vec2(1.0, 3.1));
	float annulus = smoothstep(1.18,1.25,ring_r)*(1.0-smoothstep(1.8,1.88,ring_r));
	float ring_alpha = annulus * (0.38+0.15*sin(ring_r*180.0)) * step(0.68,variation);
	vec3 ring_color = mix(vec3(0.28,0.20,0.10),vec3(0.12,0.32,0.39),variation);
	if (ring.y < 0.0) { color = mix(color,ring_color,ring_alpha); }
	float atmosphere = exp(-abs(radius-1.01)*43.0);
	vec3 light_direction = normalize(sector_light);

	vec3 normal = vec3(planet, sqrt(max(0.0, 1.0 - dot(planet, planet))));
	float sunlight = max(0.0, dot(normal, light_direction));
	float hemisphere_light = 0.19 + 0.81 * max(0.0, dot(normalize(vec3(planet, 0.17)), light_direction));
	color += vec3(0.055, 0.31, 0.46) * atmosphere * hemisphere_light * 0.74;
	if (radius < 1.0) {
		vec2 surface = vec2(atan(normal.x, max(normal.z, 0.001)), asin(clamp(normal.y, -1.0, 1.0)));
		float land = cloud_noise(surface * 5.2 + vec2(11.3 + planet_id * 7.0, 21.8));
		float wisps = noise(surface * vec2(16.0, 33.0) + land * 3.0);
		float type = mod(planet_id,4.0); // Cycle archetypes to prevent same-looking streaks.
		vec3 planet_color;
		if (type < 1.0) {
			// Ocean world, continents and cloud streaks.
			planet_color = mix(vec3(0.015,0.105,0.22),vec3(0.055,0.23,0.15),smoothstep(0.43,0.60,land));
			planet_color += vec3(0.12,0.16,0.20)*smoothstep(0.54,0.75,wisps)*0.5;
		} else if (type < 2.0) {
			// Warm gas giant with rolling latitude bands.
			float bands = 0.5+0.5*sin(surface.y*35.0+land*8.0);
			planet_color = mix(vec3(0.18,0.060,0.020),vec3(0.34,0.23,0.095),bands);
		} else if (type < 3.0) {
			// Glacial world: cyan ice shelves and pale cracks.
			planet_color = mix(vec3(0.035,0.18,0.28),vec3(0.20,0.35,0.41),smoothstep(0.35,0.65,land));
			planet_color *= 0.75+wisps*0.25;
		} else {
			// Dry, rocky world with dark mineral patches and impact texture.
			planet_color = mix(vec3(0.11,0.030,0.070),vec3(0.33,0.14,0.060),land);
			planet_color *= 0.6+noise(surface*38.0+planet_id)*0.4;
		}
		planet_color *= 0.14 + sunlight * 2.8;
		planet_color += vec3(0.028, 0.116, 0.170) * pow(1.0 - normal.z, 3.0) * sunlight;
		float silhouette = 1.0 - smoothstep(0.992, 1.0, radius);
		color = mix(color, planet_color, silhouette);
	}
	if (ring.y >= 0.0) { color = mix(color,ring_color,ring_alpha); }
	// A small cratered moon passes beside each planet with a different parallax
	// speed. These bounded analytic shapes avoid textures and extra draw nodes.
	vec2 moon_center = planet_center + vec2(mix(-170.0, 170.0, variation), -165.0);
	vec2 moon = (p - moon_center) / (26.0 + variation * 22.0);
	float moon_r = length(moon);
	if (moon_r < 1.0 && variation > 0.3) {
		vec3 moon_normal = vec3(moon, sqrt(max(0.0, 1.0 - dot(moon, moon))));
		float craters = noise(moon * 15.0 + planet_id);
		vec3 moon_color = vec3(0.24, 0.26, 0.31) * (0.12 + max(0.0, dot(moon_normal, light_direction))) * (0.55 + craters * 0.45);
		color = mix(color, moon_color, 1.0 - smoothstep(0.97, 1.0, moon_r));
	}
	float vignette = 1.0 - 0.30 * smoothstep(0.2, 0.83, length(uv - vec2(0.5)));
	COLOR = vec4(color * vignette, 1.0);
}
