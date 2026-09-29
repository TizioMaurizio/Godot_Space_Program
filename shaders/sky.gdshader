shader_type sky;
uniform float air = 1.0;
void sky() {
    vec3 d=normalize(EYEDIR);
    vec3 space=vec3(0.001,0.004,0.012);
    vec3 atmosphere=mix(vec3(0.23,0.42,0.54),vec3(0.025,0.13,0.27),clamp(d.y*0.5+0.5,0.0,1.0));
    vec3 cell=floor(d*650.0);
    float h=fract(sin(dot(cell,vec3(12.9898,78.233,45.164)))*43758.5453);
    float star=step(0.9985,h)*pow(max(0.0,1.0-length(fract(d*650.0)-0.5)*2.0),5.0);
    float sun_angle=dot(d,normalize(vec3(-0.5,0.7,0.6)));
    float sun_core=smoothstep(0.99993,0.99996,sun_angle);
    float corona=pow(max(sun_angle,0.0),1500.0)*0.22;
    // Neutral white emitter: sky blending must not turn the Sun orange in space.
    COLOR=mix(space+star*1.8,atmosphere,air)+vec3(1.0)*(sun_core*5.0+corona);
}
