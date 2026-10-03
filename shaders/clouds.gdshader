shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://shaders/planet_noise.gdshaderinc"
uniform vec3 sun_local = vec3(-0.476731,0.667424,0.572078);
uniform float cloud_phase = 0.0;
uniform float coverage = 0.88;
varying vec3 direction;
void vertex(){direction=normalize(VERTEX);}
void fragment(){
 vec3 d=normalize(direction); float cloud=cloud_field(d,cloud_phase);
 float day=dot(d,sun_local); float sunlight=smoothstep(-0.13,0.4,day);
 vec3 twilight=mix(vec3(0.08,0.11,0.18),vec3(1.0,0.58,0.35),smoothstep(-0.2,0.0,day));
 ALBEDO=mix(twilight,vec3(0.94,0.97,1.0),sunlight);
 ALPHA=cloud*coverage;
}
