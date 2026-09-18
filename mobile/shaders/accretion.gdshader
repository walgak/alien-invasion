shader_type canvas_item;
render_mode unshaded;
// Fine detail is baked once into the luminance texture; only two texture samples
// are needed per pixel. No procedural noise loops or offscreen 3D renderer.
uniform float core_radius = 31.0;
uniform float half_extent = 139.0;
uniform float visual_time = 0.0;
uniform vec4 energy_color : source_color = vec4(0.21, 0.55, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.75, 0.98, 1.0, 1.0);
uniform bool white_hole = false;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * (half_extent * 2.0);
	float radius = length(p);
	float shell = (radius - core_radius) / max(half_extent - core_radius, 1.0);
	float angle = atan(p.y, p.x);
	float direction = white_hole ? 1.0 : -1.0;
	// Follow the broad spiral with differential rotation and small radial waves.
	// The shell phase travels inward for black holes and outward for white holes.
	float flow = shell * 15.0 - direction * visual_time * 2.0;
	float radial_warp = sin(flow + sin(angle * 3.0) * 0.5) * 0.007 * smoothstep(0.0, 0.16, shell);
	float turn = angle - direction * visual_time * 0.23 + sin(flow * 0.55) * 0.022;
	// Measured centre/radius of the source disk; the physical event horizon is
	// masked separately, so cosmetic turbulence never changes the lethal radius.
	vec2 texture_center = vec2(0.496, 0.4825);
	float texture_radius = 0.106 + max(shell, 0.0) * 0.355 + radial_warp;
	vec2 uv_a = texture_center + vec2(cos(turn), sin(turn)) * texture_radius;
	vec2 uv_b = texture_center + vec2(cos(turn + 0.12), sin(turn + 0.12)) * (texture_radius + sin(flow + 1.3) * 0.0025);
	float a = texture(TEXTURE, uv_a).r;
	float b = texture(TEXTURE, uv_b).r;
	float intensity = mix(a, b, 0.20);
	float filaments = pow(max(intensity, 0.0), 0.80);
	float inner = exp(-max(shell, 0.0) * 6.0);
	vec3 gas = mix(energy_color.rgb * 0.70, energy_color.rgb, smoothstep(0.10, 0.40, intensity));
	gas = mix(gas, hot_color.rgb, smoothstep(0.48, 0.95, intensity) * (0.6 + inner * 0.4));
	float outside = smoothstep(core_radius - 0.5, core_radius + 1.0, radius);
	float envelope = (1.0 - smoothstep(0.75, 0.98, shell)) * outside;
	float alpha = clamp(filaments * 1.48, 0.0, 0.98) * envelope;
	// White plasma uses the same detailed structure, lifted into icy white/gold.
	if (white_hole) {
		gas = mix(gas, vec3(0.91, 0.98, 1.0), 0.22 + inner * 0.26);
		alpha = min(0.96, alpha * 1.13);
	}
	COLOR = vec4(gas, alpha);
}
