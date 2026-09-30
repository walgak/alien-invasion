shader_type canvas_item;
render_mode unshaded, blend_add;

// The CPU owns the safe center path and tip. This shader supplies a soft gas
// envelope, rolling blue/violet filaments, and a hot fluid core to that ribbon.
uniform float clock = 0.0;
uniform int core_count = 0;
uniform vec4 cores[8];
varying vec2 arena_position;

void vertex() {
	arena_position = VERTEX;
}

void fragment() {
	for (int i = 0; i < 8; i++) {
		if (i >= core_count) break;
		if (distance(arena_position,cores[i].xy) <= cores[i].z+0.25) discard;
	}
	float side = UV.y*2.0-1.0;
	float rolling = sin(UV.x*9.0-clock*7.0)*0.11 + sin(UV.x*17.0+clock*4.0)*0.035;
	float center = abs(side-rolling);
	float turbulence = 0.72+0.28*sin(UV.x*19.0-clock*11.0+sin(UV.x*7.0+clock*3.0));
	float vapor = pow(max(0.0,1.0-abs(side)),2.0)*0.30;
	float plasma = exp(-center*center*24.0)*0.80;
	float filament = exp(-center*center*260.0)*0.92;
	float edge = exp(-pow(abs(side+rolling*2.0)-0.48,2.0)*130.0)*0.15;
	vec3 color = vec3(0.25,0.26,1.0)*vapor + vec3(0.16,0.70,1.0)*plasma + vec3(0.84,0.98,1.0)*filament + vec3(0.76,0.32,1.0)*edge;
	float end_fade = smoothstep(1.0,0.70,abs(side));
	COLOR = vec4(color*turbulence,COLOR.a*end_fade);
}
