shader_type canvas_item;
render_mode unshaded;
uniform vec2 map_center=vec2(.5);
uniform vec2 map_span=vec2(1.0);
void fragment(){
	vec2 uv=map_center+(UV-.5)*map_span;
	vec4 color=texture(TEXTURE,uv);
	float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
	COLOR=vec4(mix(vec3(.96,.95,.92),color.rgb,color.a*inside),1.0-smoothstep(.485,.5,length(UV-.5)));
}
