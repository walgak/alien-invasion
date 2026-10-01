shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/hull_damage.gdshaderinc"
uniform int boss_kind = 0;
uniform float visual_time = 0.0;
uniform float hit_flash = 0.0;
uniform float charging = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
	// The outer pieces hover about their sockets; the central reactor and
	// spear tips remain anchored. This mesh is entirely a CanvasItem in 2D.
	vec2 p = VERTEX / 272.0;
	float floating = smoothstep(0.23, 0.37, abs(p.x));
	float breathe = sin(visual_time * 1.4 + abs(p.y) * 5.0);
	VERTEX.x += sign(p.x) * floating * (breathe * 1.6 + charging * 2.0);
	VERTEX.y += floating * sin(visual_time * 1.1 + p.y * 6.0) * 1.2;
	VERTEX = damaged_vertex(VERTEX);
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 p = UV - vec2(0.5, 0.495);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	vec3 energy = boss_kind == 0 ? vec3(0.64,0.20,1.0) : (boss_kind == 1 ? vec3(0.20,0.66,1.0) : vec3(1.0,0.38,0.06));
	float emissive = boss_kind == 0 ? max(art.b-art.g*1.2,0.0) : (boss_kind == 1 ? max(art.b-art.r*1.1,0.0) : max(art.r-art.b*1.3,0.0));
	float direction = boss_kind == 0 ? -1.0 : 1.0;
	// Traveling highlights animate the painted plasma without rotating armor
	// through the core. Black flows inward, white radiates outward.
	float flow = 0.5+0.5*sin(angle*3.0 + radius*62.0 - visual_time*direction*4.5);
	float core = 1.0-smoothstep(0.11,0.24,radius);
	art.rgb += energy*emissive*(0.12+flow*0.23+charging*0.25);
	art.rgb += energy*core*emissive*flow*0.17;
	// A soft reflection moves over the existing bevels; it never replaces the
	// baked material lighting, and leaves the black event horizon truly dark.
	float reflection = pow(max(0.0,1.0-abs(UV.x+UV.y*0.3-(0.7+sin(visual_time*0.37)*0.25))*5.0),12.0);
	float metal = (1.0-clamp(emissive*2.0,0.0,1.0))*smoothstep(0.10,0.55,length(art.rgb));
	art.rgb += vec3(0.08,0.10,0.13)*reflection*metal;
	art = damaged_hull(art, UV);
	art.rgb = mix(art.rgb,vec3(0.92,0.96,1.0),hit_flash*0.55);
	COLOR = art * vertex_tint;
}
