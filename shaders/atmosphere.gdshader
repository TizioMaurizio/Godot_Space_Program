shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add;
uniform vec3 sun_local = vec3(-0.476731,0.667424,0.572078);
varying vec3 direction;
void vertex(){direction=normalize(VERTEX);}
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.5);
 float day=dot(normalize(direction),sun_local);
 float lit=smoothstep(-0.22,0.18,day);
 vec3 tint=mix(vec3(0.8,0.21,0.045),vec3(0.055,0.33,0.78),smoothstep(-0.02,0.3,day));
 ALBEDO=tint*rim*lit; ALPHA=0.72;
}
