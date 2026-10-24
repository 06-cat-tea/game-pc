shader_type canvas_item;
render_mode unshaded;
uniform vec2 map_center=vec2(.5);
uniform vec2 map_span=vec2(1.0);
void fragment(){
	vec2 uv=map_center+(UV-.5)*map_span;
	vec2 step_uv=map_span/vec2(230.0)*.55;
	vec4 color=texture(TEXTURE,uv)*.4;
	color+=(texture(TEXTURE,uv+vec2(step_uv.x,0.0))+texture(TEXTURE,uv-vec2(step_uv.x,0.0))+texture(TEXTURE,uv+vec2(0.0,step_uv.y))+texture(TEXTURE,uv-vec2(0.0,step_uv.y)))*.15;
	color.rgb=mix(color.rgb,vec3(dot(color.rgb,vec3(.22,.65,.13))),.10);
	float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
	COLOR=vec4(mix(vec3(.96,.95,.92),color.rgb,color.a*inside),1.0-smoothstep(.485,.5,length(UV-.5)));
}
