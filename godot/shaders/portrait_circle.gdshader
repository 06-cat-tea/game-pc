shader_type canvas_item;
void fragment(){
	vec4 sample_color=texture(TEXTURE,UV);
	float edge=1.0-smoothstep(.48,.50,length(UV-vec2(.5)));
	COLOR=vec4(sample_color.rgb,sample_color.a*edge);
}
