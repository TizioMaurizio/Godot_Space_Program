float hash3(vec3 p) { p=fract(p*0.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) { float v=0.0; float a=0.5; for(int i=0;i<5;i++){v+=a*noise3(p);p=p*2.03+vec3(5.1,9.2,3.7);a*=0.5;}return v; }
float cloud_field(vec3 d, float phase) {
 float c=cos(phase),s=sin(phase); d=vec3(c*d.x-s*d.y,s*d.x+c*d.y,d.z);
 vec3 p=d*8.0+vec3(fbm(d*5.0)*2.0);
 return smoothstep(0.46,0.67,fbm(p));
}
