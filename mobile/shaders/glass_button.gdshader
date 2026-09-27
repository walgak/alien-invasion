shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float visual_time = 0.0;
uniform float available = 0.0;
uniform float selected = 0.0;
uniform float charge = 0.0;

// A thin, refracting glass shell keeps the center transparent. Circular alpha
// removes the quad corners; every button shares this inexpensive single pass.
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float mask = 1.0 - smoothstep(0.95, 1.0, r);
	vec2 normal = p / max(r, 0.001);
	float shell = exp(-pow((r - 0.83) / 0.095, 2.0));
	float swirl = sin(angle * 3.0 + visual_time * 0.55 + r * 7.0);
	vec2 offset = (normal * shell * 5.5 + vec2(-normal.y, normal.x) * swirl * shell * 1.6) * SCREEN_PIXEL_SIZE;
	vec3 behind = texture(screen_texture, SCREEN_UV + offset).rgb;
	float fresnel = pow(clamp(r, 0.0, 1.0), 5.0);
	float highlight = pow(max(0.0, sin(angle - 0.75 + sin(visual_time * 0.25) * 0.18)), 8.0);
	float around = mod(angle + 1.5707963 + 6.2831853, 6.2831853) / 6.2831853;
	float filled = step(around, charge) * exp(-pow((r - 0.91) / 0.021, 2.0));
	vec3 blue = mix(vec3(0.10,0.23,0.42),vec3(0.22,0.54,0.95),available);
	vec3 tint = behind * 0.91 + blue * (0.035 + shell * 0.16 + selected * 0.10);
	tint += vec3(0.65,0.84,1.0) * (shell * highlight * 0.30 + filled * 0.50);
	// Sampling and compositing the scene also preserves a visible displacement
	// on bright nebulae, while a soft blue shell remains legible in dark space.
	COLOR = vec4(tint, mask * (0.36 + shell * 0.49 + fresnel * 0.10));
}
