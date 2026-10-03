shader_type spatial;
render_mode unshaded;
void fragment() {
    vec2 grid = abs(fract(UV * 40.0 - 0.5) - 0.5) / max(fwidth(UV * 40.0), vec2(0.001));
    float line = 1.0 - min(min(grid.x, grid.y), 1.0);
    ALBEDO = mix(vec3(0.045,0.075,0.105),vec3(0.16,0.25,0.29),line * 0.7);
}
