shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float age = 0.0;
uniform float seed = 0.0;
uniform float aspect = 1.0;
uniform float end_padding = 0.14;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
// Piecewise-linear kinks make a snapped electrical channel; secondary plasma
// follows it with softer turbulent borders. Both endpoints stay physically fixed.
float bolt(float along,float phase) {
	float cell=along*13.0;
	float frame=floor(age*24.0)+phase;
	float jag=mix(hash(vec2(floor(cell)+seed,frame)),hash(vec2(floor(cell)+1.0+seed,frame)),fract(cell));
	return (jag-0.5)*0.22*sin(clamp(along,0.0,1.0)*3.14159265);
}
void fragment() {
	float x=(UV.x-end_padding)/max(1.0-end_padding*2.0,0.05);
	float y=UV.y-0.5;
	float t=age/0.38;
	float route=bolt(x,0.0);
	float width=max(fwidth(y),0.0035);
	float channel=exp(-pow((y-route)/width,2.0));
	float sheath=exp(-pow((y-route)/0.023,2.0));
	float corona=exp(-pow((y-route)/0.085,2.0))*noise(vec2(x*18.0,y*14.0-age*22.0));
	float fork_route=route+sin(clamp((x-0.25)/0.5,0.0,1.0)*3.14159265)*0.12;
	float fork_gate=smoothstep(0.23,0.30,x)*(1.0-smoothstep(0.67,0.77,x));
	float fork=exp(-pow((y-fork_route)/max(width*0.72,0.002),2.0))*fork_gate;
	// Propagate in a few frames, then give the contact a sharp blue-white pop.
	float travel=1.0-smoothstep(age/0.032-0.07,age/0.032+0.03,x);
	float gate=smoothstep(-0.025,0.015,x)*(1.0-smoothstep(0.985,1.025,x))*travel;
	vec2 physical=vec2(UV.x*aspect,y);
	vec2 origin=vec2(end_padding*aspect,0.0);
	vec2 target=vec2((1.0-end_padding)*aspect,0.0);
	float root=exp(-dot(physical-origin,physical-origin)*380.0);
	float hit=exp(-dot(physical-target,physical-target)*290.0)*smoothstep(0.018,0.045,age);
	float pulse=(1.0-smoothstep(0.12,1.0,t))*(0.78+0.22*sin(age*145.0));
	float opacity=((channel+fork*0.60+sheath*0.48+corona*0.26)*gate+root*0.8+hit*1.1)*pulse;
	vec3 color=mix(vec3(0.08,0.31,1.0),vec3(0.9,0.985,1.0),clamp(channel+fork+root+hit,0.0,1.0));
	COLOR=vec4(color,opacity);
}
