shader_type spatial;
render_mode cull_disabled;
uniform vec3 wave_phase = vec3(0.0);
uniform float amplitude = 0.25;
uniform float wave_number = 0.15707963;
uniform float render_scale = 1.0;
uniform bool underwater = false;
uniform vec3 sun_local = vec3(-0.476731,0.667424,0.572078);
varying vec3 body_direction;
varying float seabed;
varying vec3 water_position;
void vertex() {
    vec3 p=VERTEX/render_scale;
    vec3 angles=vec3(p.x*wave_number,p.z*wave_number*1.43,p.y*wave_number*0.71)+wave_phase;
    float wave=amplitude*(sin(angles.x)+0.4*sin(angles.y)+0.2*sin(angles.z));
    vec3 n=normalize(NORMAL);
    body_direction=normalize(vec3(UV,UV2.y)); seabed=UV2.x;
    if(render_scale<0.1){body_direction=n;seabed=-1000.0;}
    VERTEX+=n*wave*render_scale;
    vec3 gradient=amplitude*wave_number*vec3(cos(angles.x),0.142*cos(angles.z),0.572*cos(angles.y));
    NORMAL=normalize(n-(gradient-n*dot(n,gradient)));
    water_position=p;
}
void fragment() {
    float day=smoothstep(-0.1,0.4,dot(body_direction,sun_local));
    float shallow=1.0-smoothstep(0.0,22.0,-seabed);
    float foam=shallow*smoothstep(0.72,0.97,sin(water_position.x*0.8+wave_phase.x)*cos(water_position.z*0.6+wave_phase.y));
    ALBEDO=underwater ? vec3(0.01,0.08,0.12) : mix(vec3(0.015,0.11,0.17),vec3(0.06,0.23,0.25),shallow);
    ALBEDO=mix(ALBEDO,vec3(0.55,0.72,0.74),foam);
    EMISSION=ALBEDO*(0.07+0.28*day);
    ROUGHNESS=underwater ? 0.4 : 0.16;
    SPECULAR=0.85;
    METALLIC=0.25;
}
