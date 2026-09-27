shader_type canvas_item;
render_mode unshaded;
uniform float visual_time = 0.0;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 cell=floor(p), u=fract(p);
	u=u*u*(3.0-2.0*u);
	return mix(mix(hash(cell),hash(cell+vec2(1.0,0.0)),u.x),mix(hash(cell+vec2(0.0,1.0)),hash(cell+vec2(1.0)),u.x),u.y);
}

void fragment() {
	// Five overlapping soft billows form smoke, not lines. The field scrolls
	// away from the breached hull and stays subtle enough to preserve aiming.
	float cloud=0.0;
	for (int i=0;i<5;i++) {
		float age=fract(visual_time*0.6+float(i)*0.2);
		vec2 center=vec2(0.5+sin(float(i)*2.71+age*3.0)*age*0.18,0.03+age*0.9);
		vec2 d=(UV-center)/vec2(0.07+age*0.24,0.055+age*0.10);
		cloud += exp(-dot(d,d)*2.0)*sin(age*3.1415926);
	}
	float texture_noise=noise(UV*14.0-vec2(0.0,visual_time*1.4));
	float alpha=clamp(cloud*(0.18+texture_noise*0.25),0.0,0.48);
	vec3 smoke=mix(vec3(0.09,0.11,0.14),vec3(0.49,0.54,0.60),texture_noise);
	float ember=exp(-length((UV-vec2(0.5,0.035))*vec2(28.0,40.0)));
	smoke += vec3(1.0,0.24,0.045)*ember*0.6;
	COLOR=vec4(smoke,max(alpha,ember*0.52));
}
