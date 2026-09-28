shader_type canvas_item;
render_mode unshaded;
// Smooth minimum gives the surface the neck and relaxation of vacuum droplets.
// This is a single bounded quad, independent of charge and screen particle count.
uniform vec2 extent = vec2(300.0);
uniform vec2 first = vec2(90.0,150.0);
uniform vec2 second = vec2(210.0,150.0);
uniform vec2 radii = vec2(60.0);
uniform vec4 energy : source_color = vec4(0.25,0.6,1.0,1.0);
uniform float clock = 0.0;

void fragment() {
	vec2 p = UV * extent;
	float a = length(p-first)-radii.x;
	float b = length(p-second)-radii.y;
	float gap = length(second-first)-radii.x-radii.y;
	float neck = 1.0-smoothstep(0.0,22.0,gap);
	float k = max(0.001,min(radii.x,radii.y)*0.26*neck);
	float blend = clamp(0.5+0.5*(b-a)/k,0.0,1.0);
	float distance = mix(b,a,blend)-k*blend*(1.0-blend);
	float core = 1.0-smoothstep(-0.7,0.6,distance);
	float edge = exp(-abs(distance)*0.56)*(1.0-core);
	float halo = exp(-abs(distance)*0.16)*(1.0-core)*0.12;
	vec2 flow = p-mix(second,first,blend);
	float angle = atan(flow.y,flow.x);
	float caustic = 0.7+0.3*sin(angle*7.0+clock*1.8+sin(angle*3.0-clock)*0.5);
	vec3 hot = mix(energy.rgb,vec3(0.8,0.95,1.0),0.55);
	vec3 plasma = hot*edge*caustic+energy.rgb*halo;
	float alpha = max(core,clamp(edge+halo,0.0,1.0));
	// Premultiplication is avoided: opaque black is absolute inside the horizon.
	COLOR = vec4(plasma/max(alpha,0.0001),alpha);
}
