// notification_glow.glsl — Subtle green bottom border glow

const float GLOW_SIZE    = 0.04;
const float GLOW_OPACITY = 0.15;

const vec3 GREEN = vec3(0.651, 0.890, 0.631);  // catppuccin green #a6e3a1

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float glow = 1.0 - smoothstep(0.0, GLOW_SIZE, 1.0 - uv.y);

    float breath = sin(iTime * 2.513) * 0.5 + 0.5;  // 2.513 = 2π/2.5

    vec3 result = base.rgb + GREEN * glow * GLOW_OPACITY * breath;
    fragColor = vec4(result, base.a);
}
