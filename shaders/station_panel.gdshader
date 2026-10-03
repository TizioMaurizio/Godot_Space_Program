shader_type spatial;
render_mode cull_disabled;
uniform bool solar = true;
void fragment(){
 vec2 cells=UV*vec2(solar?22.0:6.0,solar?68.0:16.0);
 vec2 edge=min(fract(cells),1.0-fract(cells));
 float seam=1.0-smoothstep(0.015,0.045,min(edge.x,edge.y));
 vec3 base=solar?vec3(0.035,0.09,0.19):vec3(0.83,0.85,0.87);
 ALBEDO=mix(base,solar?vec3(0.24,0.29,0.33):vec3(0.42,0.48,0.51),seam);
 METALLIC=solar?0.3:0.15; ROUGHNESS=solar?0.35:0.7;
}
