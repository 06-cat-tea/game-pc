shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float night_strength=0.0;
uniform vec4 windows[8];
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 float mask=0.0;
 for(int i=0;i<8;i++){
  vec4 r=windows[i];
  vec2 a=smoothstep(r.xy,r.xy+vec2(.006),UV);
  vec2 b=vec2(1.0)-smoothstep(r.xy+r.zw-vec2(.006),r.xy+r.zw,UV);
  mask=max(mask,a.x*a.y*b.x*b.y*step(.001,r.z));
 }
 float brightness=smoothstep(.40,.75,dot(tex.rgb,vec3(.3,.59,.11)));
 COLOR=vec4(tex.rgb,tex.a*mask*brightness*night_strength*.9*COLOR.a);
}
