shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float age = 0.0;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=(UV-0.5)*2.0;
	float t=clamp(age/1.2,0.0,1.0);
	float expansion=0.08+0.66*sqrt(t);
	vec2 q=p/max(expansion,0.01);
	float billows=noise(q*4.0-vec2(0,age*2.1));
	billows+=noise(q*9.0+age*1.7)*0.5;
	float edge=length(q)+(billows-0.75)*0.32;
	float body=(1.0-smoothstep(0.64,1.03,edge))*(1.0-smoothstep(0.34,1.0,t));
	float heat=clamp((1.0-edge)*1.8+billows*0.36-t*0.4,0.0,1.0);
	vec3 ember=mix(vec3(0.85,0.035,0.008),vec3(1.0,0.37,0.025),smoothstep(0.08,0.58,heat));
	vec3 flame=mix(ember,vec3(1.0,0.70,0.22),smoothstep(0.57,0.97,heat));
	// Keep flame detail orange against bright nebulae instead of clipping the
	// whole fireball to white. Only the short initial ignition flashes white.
	flame=mix(flame,vec3(1.0,0.95,0.78),exp(-t*25.0)*exp(-dot(q,q)*4.0));
	float glow=exp(-dot(q,q)*2.3)*(1.0-t)*0.18;
	COLOR=vec4(flame,(body+glow)*0.83);
}
