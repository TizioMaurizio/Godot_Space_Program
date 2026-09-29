shader_type spatial;
render_mode diffuse_burley;
varying vec3 sphere_point;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 38.719))) * 43758.5453); }
float noise3(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
    mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { sphere_point = normalize(VERTEX); }
void fragment() {
    vec3 p=sphere_point*5.0;
    float land=noise3(p)+0.32*noise3(p*2.3)+0.12*noise3(p*6.5);
    vec3 ocean=vec3(0.018,0.105,0.17);
    vec3 ground=mix(vec3(0.13,0.24,0.19),vec3(0.37,0.40,0.27),noise3(p*4.0));
    vec3 color=mix(ocean,ground,smoothstep(0.67,0.70,land));
    float ice=smoothstep(0.83,0.98,abs(sphere_point.z));
    color=mix(color,vec3(0.73,0.83,0.85),ice);
    float cloud=smoothstep(0.73,0.91,noise3(p*2.1+4.0)+0.23*noise3(p*7.0));
    ALBEDO=mix(color,vec3(0.77,0.84,0.86),cloud*0.7);
    ROUGHNESS=0.88;
}
