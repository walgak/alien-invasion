shader_type canvas_item;
render_mode unshaded;
uniform bool side_ports = false;
uniform bool laser_port = false;
uniform bool recovering = false;
uniform float visual_time = 0.0;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

void fragment() {
	vec4 hull = texture(TEXTURE, UV);
	// Exposed ends of the wing cannons retract for single/laser. The mask ends
	// before the wings, so the hull itself is never cut away.
	float port_x = abs(UV.x - 0.5);
	float cannon = step(0.193, port_x) * (1.0-step(0.246, port_x));
	cannon *= 1.0-smoothstep(0.467, 0.498, UV.y);
	if (!side_ports) { hull.a *= 1.0-cannon; }
	// Preserve baked reflections; blue emissive fittings breathe gently.
	float blue = smoothstep(0.10, 0.32, hull.b-max(hull.r,hull.g*0.77));
	hull.rgb += vec3(0.015,0.085,0.16)*blue*(0.7+0.3*sin(visual_time*3.0));
	vec2 nose_uv = (UV-vec2(0.5,0.047))*vec2(95.0,35.0);
	float nose = exp(-dot(nose_uv,nose_uv));
	if (laser_port) { hull.rgb += vec3(0.32,0.7,0.9)*nose; }
	if (recovering) { hull.rgb = mix(hull.rgb, vec3(0.65,0.88,1.0), 0.10+0.06*sin(visual_time*10.0)); }
	COLOR = hull * vertex_tint;
}
