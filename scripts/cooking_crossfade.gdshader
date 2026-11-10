shader_type canvas_item;
uniform sampler2D next_texture : source_color, filter_linear;
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;
// First-side sprites have different silhouettes. Recolor one fixed source
// instead of crossfading their edges; keep its alpha and outline unchanged.
uniform bool color_only = false;
uniform vec4 raw_color : source_color = vec4(1.0, 0.941176, 0.823529, 1.0);
uniform vec4 color_from : source_color = vec4(1.0);
uniform vec4 color_to : source_color = vec4(1.0);
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 first = texture(TEXTURE, UV);
	vec4 second = texture(next_texture, UV);
	float alpha = mix(first.a, second.a, blend_amount);
	vec3 premultiplied = mix(first.rgb * first.a, second.rgb * second.a, blend_amount);
	if (color_only) {
		float fill_mask = smoothstep(0.62, 0.80, min(first.r, first.g));
		vec3 baked = first.rgb * mix(color_from.rgb, color_to.rgb, blend_amount) / raw_color.rgb;
		COLOR = vec4(mix(first.rgb, baked, fill_mask), first.a) * tint;
	} else {
		COLOR = vec4(premultiplied / max(alpha, 0.00001), alpha) * tint;
	}
}
