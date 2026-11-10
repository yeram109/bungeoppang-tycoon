shader_type canvas_item;
uniform sampler2D next_texture : source_color, filter_linear;
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 first = texture(TEXTURE, UV);
	vec4 second = texture(next_texture, UV);
	float alpha = mix(first.a, second.a, blend_amount);
	vec3 premultiplied = mix(first.rgb * first.a, second.rgb * second.a, blend_amount);
	COLOR = vec4(premultiplied / max(alpha, 0.00001), alpha) * tint;
}
