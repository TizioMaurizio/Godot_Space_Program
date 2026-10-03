shader_type sky;
uniform float air = 1.0;
uniform bool underwater = false;
uniform vec3 local_up = vec3(0.0,1.0,0.0);
uniform vec3 sun_direction = vec3(-0.476731,0.667424,0.572078);
void sky() {
    vec3 d=normalize(EYEDIR);
    vec3 space=vec3(0.001,0.004,0.012);
    float elevation=dot(d,local_up);
    float sun_elevation=dot(local_up,sun_direction);
    float day=smoothstep(-0.18,0.18,sun_elevation);
    float horizon=pow(1.0-abs(elevation),5.0);
    vec3 atmosphere=mix(vec3(0.025,0.13,0.31),vec3(0.36,0.59,0.72),horizon);
    float sunset=(1.0-smoothstep(0.0,0.35,abs(sun_elevation)))*horizon*pow(max(0.0,dot(d,sun_direction)*0.5+0.5),5.0);
    atmosphere=mix(atmosphere,vec3(0.8,0.24,0.07),sunset)*day;
    vec3 cell=floor(d*650.0);
    float h=fract(sin(dot(cell,vec3(12.9898,78.233,45.164)))*43758.5453);
    float star=step(0.9985,h)*pow(max(0.0,1.0-length(fract(d*650.0)-0.5)*2.0),5.0);
    float sun_angle=dot(d,sun_direction);
    float sun_core=smoothstep(0.99993,0.99996,sun_angle);
    float corona=pow(max(sun_angle,0.0),1500.0)*0.22;
    // Neutral white emitter: sky blending must not turn the Sun orange in space.
    COLOR=mix(space+star*1.8*(1.0-air*day),atmosphere,air*day)+vec3(1.0)*(sun_core*5.0+corona);
    if(underwater) { COLOR=vec3(0.008,0.065,0.095); }
}
