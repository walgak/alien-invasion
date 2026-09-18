shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 engine_color : source_color = vec4(0.145,0.55,1.0,1.0);
uniform float engine_load = 0.0;
uniform float visual_time = 0.0;
uniform float phase = 0.0;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}

void fragment() {
	// The hot mouth opens into turbulent, feathery plasma. Longitudinal advection
	// moves noise out of the nozzle; no strokes define the flame silhouette.
	float plume_length = mix(0.17,0.94,engine_load);
	float y = max(UV.y-0.018,0.0)/plume_length;
	float x = (UV.x-0.5)*2.0;
	float clock = visual_time*7.0+phase;
	float n = noise(vec2(x*9.0+phase,y*11.0-clock));
	float fine = noise(vec2(x*23.0-phase,y*29.0-clock*1.8));
	float curl = sin(y*22.0-clock*1.7+sin(y*9.0+clock))*0.13*y;
	// Broader billows and a widening core keep the plume from reading as a laser.
	float spread = sin(clamp(y,0.0,1.0)*3.14159);
	float width = 0.25 + 0.30*spread + (n-0.5)*0.34*y;
	float profile = exp(-pow(abs(x+curl)/max(width,0.045),2.0)*1.9);
	float tail = (1.0-smoothstep(0.56,1.0,y)) * smoothstep(0.0,0.022,UV.y);
	float plasma = profile * tail * (0.56+n*0.45+fine*0.25);
	float core_width = 0.12+0.07*spread+(fine-0.5)*0.05*y;
	float core = exp(-pow(abs(x+curl*0.6)/core_width,2.0)*1.5) * (1.0-smoothstep(0.25,0.78,y));
	float bloom = exp(-abs(x)*6.0)*(1.0-smoothstep(0.0,0.7,y))*0.24;
	vec3 hot = mix(engine_color.rgb,vec3(0.84,0.96,1.0),0.71);
	vec3 color = mix(engine_color.rgb,hot,clamp(core*0.9,0.0,1.0));
	COLOR = vec4(color, clamp(plasma+core*0.25+bloom,0.0,1.0) * (1.0-smoothstep(0.92,1.0,abs(x))));
}
