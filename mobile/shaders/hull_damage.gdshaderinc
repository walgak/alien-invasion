// Shared material damage for both player and small aliens. It only modifies
// rendered vertices/texels: collisions, aim origins, and steering stay exact.
uniform float hull_damage = 0.0;
uniform float damage_time = 0.0;

float damage_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

vec2 damaged_vertex(vec2 point) {
	float amount = clamp(hull_damage, 0.0, 2.0);
	float wobble = sin(damage_time * 7.3) * 0.011 * amount;
	wobble += sin(damage_time * 13.7) * 0.007 * amount * amount;
	mat2 twist = mat2(vec2(cos(wobble), sin(wobble)), vec2(-sin(wobble), cos(wobble)));
	return twist * point + vec2(sin(damage_time * 9.1) * 0.3 * amount, 0.0);
}

vec4 damaged_hull(vec4 hull, vec2 uv) {
	float first = smoothstep(0.0, 1.0, hull_damage);
	float severe = smoothstep(1.0, 2.0, hull_damage);
	vec2 p = uv - vec2(0.31, 0.54);
	float jagged = damage_hash(floor(uv * 53.0));
	float scar = 1.0-smoothstep(0.082, 0.17, length(p * vec2(0.90, 1.7)) + jagged * 0.025);
	vec2 q = uv-vec2(0.67,0.43);
	float scar2 = 1.0-smoothstep(0.072,0.145,length(q*vec2(1.0,1.4))+jagged*0.03);
	float damage = clamp(scar * first + scar2 * severe, 0.0, 1.0);
	// Dark torn plating, raw silver chip edges, and a small ember in the breach.
	hull.rgb = mix(hull.rgb, vec3(0.012,0.018,0.026), damage * 0.82);
	float chips = step(0.75, jagged) * damage;
	hull.rgb += vec3(0.67,0.72,0.79) * chips * (0.65+severe*0.35);
	float cut = exp(-length(p*vec2(2.5,0.9))*49.0) * first;
	hull.rgb += vec3(1.0,0.28,0.05) * cut * (0.38+0.12*sin(damage_time*11.0));
	// Only the second hit opens tiny actual holes in already damaged plating.
	hull.a *= 1.0-step(0.93,jagged)*scar2*severe*0.7;
	return hull;
}
