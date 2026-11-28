shader_type canvas_item;

uniform sampler2D gradient_map : source_color, filter_linear, repeat_disable;
varying vec4 sprite_modulate;

void vertex() {
	sprite_modulate = COLOR;
}

void fragment() {
	vec4 portrait = texture(TEXTURE, UV);
	float luminance = dot(portrait.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 mapped = texture(gradient_map, vec2(luminance, 0.5)).rgb;
	COLOR = vec4(mapped, portrait.a) * sprite_modulate;
}
