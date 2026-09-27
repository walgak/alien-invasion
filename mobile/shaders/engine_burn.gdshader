shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 engine_color : source_color = vec4(0.145,0.55,1.0,1.0);
uniform float engine_load = 0.0;
uniform float visual_time = 0.0;
uniform float phase = 0.0;
uniform vec2 surface_size = vec2(38.08,228.0);
uniform vec2 nozzle_pixel = vec2(19.04,2.0);
uniform float nozzle_width = 5.6;
uniform vec2 gravity_tail_direction = vec2(0.0,1.0);
uniform float gravity_tail_strength = 0.0;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}

void fragment() {
	// The hot mouth opens into turbulent, feathery plasma. Longitudinal advection
	// moves noise out of the nozzle; no strokes define the flame silhouette.
	// Rising engine effort is unmistakable well before the event horizon. The
	// dormant nozzle remains the same small light; color still comes from its owner.
	float effort = pow(clamp(engine_load,0.0,1.0),0.58);
	vec2 pixel = UV * surface_size - nozzle_pixel;
	// Extra transparent space follows deflected wisps, while these coordinates
	// keep the existing blue/violet engine mouth at its original physical size.
	vec2 nozzle_uv = vec2(pixel.x / (nozzle_width * 6.8) + 0.5, (pixel.y + 2.0) / 228.0);
	float plume_length = mix(0.075,0.96,effort);
	float y = max(nozzle_uv.y-0.018,0.0)/plume_length;
	float x = (nozzle_uv.x-0.5)*2.0;
	float clock = visual_time*7.0+phase;
	float n = noise(vec2(x*9.0+phase,y*11.0-clock));
	float fine = noise(vec2(x*23.0-phase,y*29.0-clock*1.8));
	float curl = sin(y*22.0-clock*1.7+sin(y*9.0+clock))*0.13*y;
	// Broader billows and a widening core keep the plume from reading as a laser.
	float spread = sin(clamp(y,0.0,1.0)*3.14159);
	float width = mix(0.18,0.34,effort) + 0.34*spread + (n-0.5)*0.34*y;
	float profile = exp(-pow(abs(x+curl)/max(width,0.045),2.0)*1.9);
	float tail = (1.0-smoothstep(0.56,1.0,y)) * smoothstep(0.0,0.022,nozzle_uv.y);
	float plasma = profile * tail * (0.56+n*0.45+fine*0.25);
	float core_width = 0.12+0.07*spread+(fine-0.5)*0.05*y;
	float core = exp(-pow(abs(x+curl*0.6)/core_width,2.0)*1.5) * (1.0-smoothstep(0.25,0.78,y));
	float bloom = exp(-abs(x)*6.0)*(1.0-smoothstep(0.0,0.7,y))*0.24;
	vec3 hot = mix(engine_color.rgb,vec3(0.84,0.96,1.0),0.71);
	vec3 color = mix(engine_color.rgb,hot,clamp(core*0.9,0.0,1.0));
	float alpha = clamp(plasma+core*0.25+bloom,0.0,1.0) * (1.0-smoothstep(0.92,1.0,abs(x))) * smoothstep(-1.0,2.0,pixel.y);
	// Cool, translucent exhaust is peeled toward the nearest black hole. Three
	// broad turbulent wisps share the engine colour and retain a bright mouth;
	// they are fluid surfaces rather than stroked tails or spawned particles.
	vec2 axis = normalize(gravity_tail_direction + vec2(0.00001));
	vec2 perpendicular = vec2(-axis.y,axis.x);
	vec2 plume_pixel = pixel - vec2(0.0,6.0);
	float along = dot(plume_pixel,axis);
	float fraction = along / max(1.0,(140.0+140.0*effort)*gravity_tail_strength);
	float across = dot(plume_pixel,perpendicular);
	float wisps = 0.0;
	for (int i = 0; i < 3; i++) {
		float strand = float(i)-1.0;
		float swirl = sin(fraction*12.0-clock*0.65+strand*2.1) * fraction * (4.0+9.0*fraction);
		float center = swirl + strand*(3.0+fraction*7.0);
		float feather = noise(vec2(across*0.17+strand*9.0,along*0.06-clock*0.6));
		float width = 2.0+fraction*7.0+feather*5.0;
		float envelope = exp(-pow((across-center)/max(width,1.0),2.0));
		wisps += envelope * (0.35+feather*0.65) * smoothstep(0.0,0.10,fraction) * (1.0-smoothstep(0.35,1.0,fraction));
	}
	wisps *= gravity_tail_strength * 0.24;
	vec3 weighted = color*(1.0+effort*0.38)*alpha + engine_color.rgb*wisps;
	float combined_alpha = clamp(alpha+wisps,0.0,1.0);
	COLOR = vec4(weighted/max(combined_alpha,0.001),combined_alpha);
}
