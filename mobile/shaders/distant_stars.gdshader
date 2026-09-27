shader_type canvas_item;
render_mode unshaded;
// This shader never samples refracted coordinates. Stars remain behind the gas
// and planets, with only extremely slow parallax and a restrained twinkle.
uniform vec2 arena_size = vec2(540.0,960.0);
uniform float visual_time = 0.0;
float hash21(vec2 p) {
	p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);
}
vec3 stars(vec2 p,float spacing,float seed) {
	vec2 grid=p/spacing, cell=floor(grid);
	float chance=hash21(cell+seed);
	vec2 offset=vec2(hash21(cell+seed+9.1),hash21(cell+seed+38.4));
	vec2 delta=(fract(grid)-mix(vec2(0.16),vec2(0.84),offset))*spacing;
	float size=mix(0.40,0.88,chance), d=dot(delta,delta);
	float core=exp(-d/(size*size)), halo=exp(-d/(size*size*11.0))*0.09;
	float twinkle=0.92+0.08*sin(visual_time*(0.13+chance*0.12)+chance*73.0);
	return mix(vec3(0.36,0.60,0.92),vec3(0.93,0.86,0.73),offset.x)*(core+halo)*twinkle*step(0.42,chance);
}
void fragment() {
	vec2 p=UV*arena_size;
	vec3 sky=vec3(0.004,0.009,0.023);
	sky+=stars(p-vec2(0.0,visual_time*0.12),62.0,11.7)*0.72;
	sky+=stars(p-vec2(19.0,visual_time*0.20),141.0,82.1)*0.87;
	COLOR=vec4(sky,1.0);
}
