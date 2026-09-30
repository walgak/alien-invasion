shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float logical_radius = 56.4;
uniform float visual_time = 0.0;
uniform float strength = 1.0;
uniform float hit_age = 10.0;
uniform vec2 hit_position = vec2(0.0);

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float hex_mesh(vec2 p) {
	vec2 period=vec2(1.7320508,3.0);
	vec2 a=mod(p,period)-period*0.5;
	vec2 b=mod(p-period*0.5,period)-period*0.5;
	vec2 local=dot(a,a)<dot(b,b)?a:b;
	float edge=0.8660254-max(dot(abs(local),vec2(0.8660254,0.5)),abs(local.x));
	// Derivatives keep subpixel hex borders visible at actual phone size, rather
	// than disappearing between pixels as the curved shell moves.
	float width=max(0.040,fwidth(edge)*0.72);
	return 1.0-smoothstep(width*0.20,width,abs(edge));
}
void fragment() {
	vec2 p=(UV-0.5)*2.36;
	float r=length(p);
	float aa=max(fwidth(r),0.65/logical_radius);
	float interior=1.0-smoothstep(1.0-aa,1.0+aa,r);
	float z=sqrt(max(0.0,1.0-r*r));
	float fresnel=pow(1.0-z,2.8);
	// Spherical projection bends hexagons around the shell; only their dimmer
	// front hemisphere crosses the ship, keeping the cockpit and weapons clear.
	vec2 sphere=p/(0.66+z*0.54);
	vec2 drift=vec2(visual_time*0.045,-visual_time*0.036);
	float turbulence=noise(sphere*4.7+drift);
	vec2 folded=sphere+vec2(sin(sphere.y*8.0+visual_time*0.5),cos(sphere.x*7.0-visual_time*0.4))*0.019;
	float mesh=hex_mesh(folded*7.4);
	float filaments=pow(max(0.0,1.0-abs(sin((sphere.y+sphere.x*0.38)*9.0+turbulence*9.0-visual_time*0.9))),9.0);
	// Only the soft halo is reduced to 10%; the existing refraction lives in
	// space_folds and is unchanged. Sharp mesh and flowing color carry contrast.
	float glow=exp(-pow((r-1.005)/0.065,2.0))*0.018;
	float ripple=exp(-pow((length(p-hit_position)-hit_age*4.6)/0.075,2.0))*(1.0-smoothstep(0.0,0.55,hit_age));
	vec3 blue=vec3(0.055,0.30,1.0);
	vec3 ice=vec3(0.34,0.77,1.0);
	float color_phase=0.5+0.5*sin(turbulence*5.0+visual_time*0.75);
	vec3 iridescent=mix(vec3(0.36,0.14,1.0),vec3(0.07,0.78,1.0),color_phase);
	// Most of the light hugs the curved limb. The dimmer central mesh still
	// shows the sphere's shape without painting over the ship or its gunfire.
	vec3 color=blue*mesh*(0.22+fresnel*0.92)+iridescent*filaments*(0.12+fresnel*0.84);
	color+=blue*fresnel*0.016+ice*mesh*fresnel*filaments*0.64;
	// There is no separately painted circular border. The curved hex mesh and
	// shifting electric flow define the limb; the background supplies the warp.
	color+=ice*(glow+ripple*0.65);
	float shell=0.94*strength;
	COLOR=vec4(color*shell,clamp(interior+glow,0.0,1.0));
}
