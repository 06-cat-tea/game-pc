shader_type canvas_item;
uniform float scene_clock=0.0;
void vertex(){VERTEX.x+=sin(UV.y*4.0+scene_clock*1.4)*UV.y*3.0;}
