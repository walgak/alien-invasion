shader_type canvas_item;
render_mode unshaded;
// Six baked, detailed minerals share one texture. Flat green is a production
// key only: remove it per sample, including the filtered edge, at draw time.
// The original generated atlas remains intact and can be replaced independently.
uniform vec2 tile_origin = vec2(0.0);
uniform bool icy = false;
uniform float visual_time = 0.0;
uniform float tumble = 0.0;
uniform float hit_flash = 0.0;
uniform float damage = 0.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float excess_green = art.g - max(art.r, art.b);
	float alpha = 1.0 - smoothstep(0.12,0.55,excess_green);
	// Unmix the green screen at antialiased edges instead of leaving neon rims.
	vec3 mineral = clamp((art.rgb - vec3(0.0,1.0-alpha,0.0))/max(alpha,0.01),0.0,1.0);
	vec2 local = ((UV-tile_origin)*vec2(3.0,2.0)-vec2(0.5))*2.0;
	vec2 light = vec2(-0.50*cos(tumble)-0.60*sin(tumble),0.50*sin(tumble)-0.60*cos(tumble));
	float face = max(0.0,1.0-dot(local,local));
	float reflection = pow(max(0.0,dot(vec3(local,sqrt(face)),normalize(vec3(light,1.5)))),22.0);
	float heat = max(mineral.r-max(mineral.g*0.9,mineral.b),0.0);
	float breath = sin(visual_time*2.4+local.x*4.0+local.y*5.0)*0.05;
	mineral *= 1.0 + heat*(breath+damage*0.16);
	mineral += vec3(0.50,0.74,0.88)*reflection*(icy?0.12:0.055);
	mineral *= 1.0-damage*0.10;
	mineral = mix(mineral,vec3(0.83,0.96,1.0),hit_flash*0.65);
	COLOR = vec4(mineral,alpha*art.a);
}
