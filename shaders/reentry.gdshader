shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 0.0;
uniform float clock = 0.0;
uniform bool shock = false;
void fragment() {
    float ripple = 0.8 + 0.2 * sin(UV.x * 65.0 + UV.y * 21.0 - clock * 18.0);
    float strands = 0.5 + 0.5 * sin(UV.x * 107.0 - UV.y * 7.0 + clock * 3.0);
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
    float trail = pow(1.0 - UV.y, 1.4);
    float shape = shock ? (0.32 + edge * 0.68) : trail * (0.3 + edge * 0.7);
    vec3 hot = mix(vec3(1.0, 0.1, 0.01), vec3(1.0, 0.48, 0.12), strength);
    ALBEDO = hot;
    EMISSION = hot * strength * 1.8;
    ALPHA = clamp(strength * shape * ripple * (0.5 + strands * 0.5), 0.0, 0.8);
}
