shader_type canvas_item;
uniform sampler2D grass : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D sand : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D pavement : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D road_mask : filter_linear;
uniform int layer_kind = 0;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
	vec2 grid=vec2(world.x/96.0+world.y/48.0,world.y/48.0-world.x/96.0);
	vec2 uv=grid/3.4;
	float mask=texture(road_mask,grid/vec2(64.0,48.0)).r;
	float noise=sin(grid.x*1.71+sin(grid.y*1.13))*sin(grid.y*1.95+grid.x*.34);
	float broad=.96+.035*sin(grid.x*.37+grid.y*.23)+.025*cos(grid.y*.41-grid.x*.17);
	vec3 tone=texture(grass,uv).rgb*broad;
	float alpha=texture(TEXTURE,UV).a;
	if(layer_kind==1){tone=mix(texture(dirt,uv*.83).rgb,texture(sand,uv*.83).rgb,.22);alpha*=smoothstep(.025,.48,mask+noise*.025)*.90;}
	if(layer_kind==2){tone=texture(pavement,uv*1.22).rgb;alpha*=smoothstep(.36,.87,mask+noise*.04)*.94;}
	COLOR=vec4(tone,alpha);
}
