shader_type spatial;
render_mode cull_disabled, unshaded;
#include "res://shaders/planet_noise.gdshaderinc"
uniform bool lunar = false;
uniform vec3 sun_local = vec3(-0.476731,0.667424,0.572078);
uniform float cloud_phase = 0.0;
varying float terrain_height;
varying vec3 body_direction;
varying vec3 surface_normal;
void vertex() { terrain_height=UV2.x; body_direction=normalize(vec3(UV,UV2.y)); surface_normal=NORMAL; }
void fragment() {
    float detail=noise3(body_direction*380.0);
    vec3 grass=mix(vec3(0.10,0.19,0.10),vec3(0.22,0.29,0.14),detail);
    vec3 sand=vec3(0.48,0.41,0.26);
    vec3 rock=vec3(0.28,0.28,0.25);
    vec3 color=mix(sand,grass,smoothstep(5.0,70.0,terrain_height));
    color=mix(color,rock,smoothstep(1100.0,2200.0,terrain_height));
    color=mix(color,vec3(0.8,0.85,0.87),smoothstep(2800.0,4200.0,terrain_height));
    if(lunar) { color=mix(vec3(0.22,0.23,0.24),vec3(0.43,0.42,0.40),detail); }
    float day=dot(normalize(body_direction),sun_local);
    float clouds=cloud_field(normalize(body_direction),cloud_phase);
    float lighting=0.035+0.965*smoothstep(-0.07,0.65,day);
    if(lunar){lighting=0.018+0.982*max(0.0,dot(normalize(surface_normal),sun_local));}
    float population=smoothstep(0.55,0.66,fbm(body_direction*31.0));
    float towns=smoothstep(0.72,0.90,noise3(body_direction*2200.0));
    float land=smoothstep(8.0,50.0,terrain_height)*(1.0-smoothstep(900.0,1900.0,terrain_height));
    float night=1.0-smoothstep(-0.15,0.08,day);
    vec3 cities=vec3(1.0,0.55,0.18)*population*towns*land*night*2.0;
    if(lunar) { clouds=0.0; cities=vec3(0.0); }
    ALBEDO=color*lighting*(1.0-clouds*0.22)+cities*(1.0-clouds*0.9);
    ROUGHNESS=0.92;
}
