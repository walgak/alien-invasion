shader_type canvas_item;
render_mode unshaded;

// The supplied sheets are RGB on a black matte rather than equally spaced
// transparent sprites. Bounds and reactor pivots come from the source pixels;
// sampling through them avoids both neighboring-frame bleed and center jumps.
uniform sampler2D sheet_texture : filter_linear, repeat_disable;
uniform vec4 frame_a;
uniform vec4 frame_b;
uniform vec2 pivot_a;
uniform vec2 pivot_b;
uniform vec2 pixels_per_unit = vec2(1.0);
uniform float frame_mix = 0.0;
uniform float opacity = 1.0;
uniform float black_core = 0.0;
uniform float inward_fold = 0.0;
const vec2 SHEET_SIZE = vec2(2172.0, 724.0);
const float QUAD_SIZE = 360.0;

vec4 extract_frame(vec2 offset, vec4 bounds, vec2 pivot) {
	vec2 pixel = pivot + offset * pixels_per_unit;
	vec2 inset = min(pixel - bounds.xy, bounds.zw - pixel);
	float inside = smoothstep(0.0, 26.0, min(inset.x, inset.y));
	// The original strips overlap their explosion tails. A broad round falloff
	// removes the rectangular crop edge without inventing neighboring debris.
	vec2 framed = (pixel - (bounds.xy + bounds.zw) * 0.5) / ((bounds.zw - bounds.xy) * 0.5);
	inside *= 1.0 - smoothstep(0.78, 1.06, length(framed));
	vec3 rgb = texture(sheet_texture, clamp(pixel, bounds.xy, bounds.zw) / SHEET_SIZE).rgb;
	float light = max(max(rgb.r, rgb.g), rgb.b);
	// Unmatte the antialiased glow. Dark empty pixels are transparent, while
	// painted armor and sparks retain their original color and detail.
	float alpha = smoothstep(0.008, 0.10, light) * inside;
	return vec4(rgb * inside, alpha);
}

void fragment() {
	vec2 offset = (UV - vec2(0.5)) * QUAD_SIZE;
	// Before pieces burst outward, the black boss's sheet also compresses
	// inward gently. This is cosmetic and never changes the death field.
	float radius = length(offset);
	float fold = inward_fold * smoothstep(26.0, 145.0, radius);
	vec2 folded = offset * (1.0 + fold * 0.12);
	vec4 a = extract_frame(folded, frame_a, pivot_a);
	vec4 b = extract_frame(folded, frame_b, pivot_b);
	vec4 art = mix(a, b, frame_mix);
	// Preserve an opaque event horizon before the real death well opens; a
	// black matte key must not accidentally reveal stars through its core.
	float core = (1.0 - smoothstep(black_core - 1.2, black_core, radius)) * step(0.1, black_core);
	art.a = max(art.a, core);
	art.rgb *= 1.0 - core;
	COLOR = vec4(art.rgb / max(art.a, 0.001), art.a * opacity);
}
