shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float age = 0.0;
uniform float seed = 0.0;
uniform float aspect = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=(UV-0.5)*vec2(aspect,1.0);
	float t=age/0.38;
	float flow=noise(vec2(UV.x*11.0+seed,age*35.0));
	float kink=(flow-0.5)*0.20*sin(UV.x*3.14159);
	float y=abs(p.y+kink);
	float channel=exp(-y*y*1800.0)*(0.5+0.5*noise(vec2(UV.x*43.0,age*70.0)));
	float mist=exp(-y*y*130.0)*noise(vec2(UV.x*17.0,p.y*24.0-age*25.0));
	float envelope=smoothstep(0.02,0.21,UV.x)*(1.0-smoothstep(0.79,0.98,UV.x));
	float roots=exp(-dot(p-vec2(-aspect*0.28,0),p-vec2(-aspect*0.28,0))*130.0);
	roots+=exp(-dot(p-vec2(aspect*0.28,0),p-vec2(aspect*0.28,0))*130.0);
	float pulse=(1.0-smoothstep(0.12,1.0,t))*(0.7+0.3*sin(age*130.0));
	float opacity=(channel+mist*0.65+roots*0.6)*envelope*pulse;
	vec3 color=mix(vec3(0.16,0.42,1.0),vec3(0.9,0.98,1.0),clamp(channel+roots,0.0,1.0));
	COLOR=vec4(color,opacity);
}
