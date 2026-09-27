shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/hull_damage.gdshaderinc"
uniform vec4 emission_color : source_color = vec4(0.7,0.3,1.0,1.0);
uniform float visual_time = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
	VERTEX = damaged_vertex(VERTEX);
}

void fragment() {
	vec4 hull = texture(TEXTURE, UV);
	// Replace only saturated violet fittings. Neutral graphite and baked silver
	// reflections keep their original value, shape and texture detail.
	float purple = smoothstep(0.025,0.19,min(hull.r,hull.b)-hull.g);
	float light = max(max(hull.r,hull.g),hull.b);
	vec3 glow = emission_color.rgb * light;
	glow += vec3(1.0) * pow(light,5.0) * 0.22;
	hull.rgb = mix(hull.rgb,glow,purple);
	hull.rgb += emission_color.rgb * purple * (0.03+0.015*sin(visual_time*3.0));
	COLOR = damaged_hull(hull, UV) * vertex_tint;
}
