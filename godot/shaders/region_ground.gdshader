shader_type canvas_item;
uniform sampler2D ground_art : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D road_art : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D terrain_mask : filter_linear;
uniform vec2 map_cells=vec2(64.0,48.0);
uniform vec4 water_color : source_color=vec4(.3,.5,.6,1.0);
uniform int layer_kind=0;
uniform int biome=0;
uniform float scene_clock=0.0;
uniform float night_strength=0.0;
uniform vec2 lamp_positions[8];
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
	vec2 grid=vec2(world.x/96.0+world.y/48.0,world.y/48.0-world.x/96.0);
	vec3 mask=texture(terrain_mask,grid/map_cells).rgb;
	float variation=.94+.045*sin(grid.x*.37+grid.y*.22)+.03*cos(grid.y*.46-grid.x*.19);
	vec3 base=texture(ground_art,grid/5.0).rgb*variation;
	vec3 color=mix(base,vec3(.43,.40,.35),mask.b*.45);float alpha=1.0;
	if(layer_kind==1){
		color=texture(road_art,grid/4.0).rgb;
		if(biome==0)color=mix(color,base,.34);
		if(biome==1)color=mix(color,vec3(.52,.40,.28),.40);
		if(biome==2)color=mix(color,vec3(.43,.46,.52),.26);
		alpha=smoothstep(.10,.88,mask.r)*.94;
	}
	if(layer_kind==2){
		float ripple=sin(grid.x*2.6+grid.y*1.5+scene_clock*.9)*sin(grid.y*2.4-scene_clock*.6);
		float broad=sin(grid.x*.45+scene_clock*.15)*.03;
		color=water_color.rgb*(.94+ripple*.045+broad);
		float shore=(1.0-smoothstep(.48,.94,mask.g))*smoothstep(.10,.42,mask.g);
		float crest=pow(max(0.0,sin(grid.x*1.6-grid.y*.8+scene_clock*.8)),14.0);
		color+=vec3(.28,.30,.26)*shore*(.55+crest*.4);
		color+=vec3(.10,.14,.15)*pow(max(0.0,ripple),6.0)*.32;
		for(int i=0;i<8;i++){
		 vec2 delta=grid-lamp_positions[i];
		 float pool=exp(-dot(delta,delta)/17.0);
		 float stripe=pow(max(0.0,sin(grid.y*11.0+sin(grid.x*2.0)+scene_clock*.6)),4.0);
		 color+=vec3(1.0,.60,.21)*pool*stripe*night_strength*1.6;
		}
		alpha=smoothstep(.10,.86,mask.g);
	}
	COLOR=vec4(color,alpha);
}
