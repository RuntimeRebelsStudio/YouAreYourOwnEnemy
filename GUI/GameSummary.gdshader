shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform vec4 color_tint : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);
	COLOR = mix(color, color_tint, color_tint.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
