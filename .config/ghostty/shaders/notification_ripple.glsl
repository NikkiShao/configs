// notification_ripple.glsl — Corner ripple from bottom-left

// ─── Tunables ────────────────────────────────────────────────────────
const float RIPPLE_SPEED    = 4.0;          // expansion speed
const float RIPPLE_COUNT    = 3.0;          // number of rings
const float RIPPLE_WIDTH    = 0.08;         // ring thickness
const float DISTORT_AMOUNT  = 0.004;        // lens distortion strength
const float TINT_STRENGTH   = 0.04;         // blue tint intensity
const float TOTAL_DURATION  = 0.8;

const vec3 TINT_COLOR = vec3(0.537, 0.706, 0.980);  // #89b4fa

// ─── Main ────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float phase = mod(iTime, TOTAL_DURATION);

    // Origin: bottom-left corner
    vec2 origin = vec2(0.0, 0.0);
    float aspect = iResolution.x / iResolution.y;
    vec2 delta = (uv - origin) * vec2(aspect, 1.0);
    float dist = length(delta);
    vec2 dir = dist > 0.0 ? delta / dist : vec2(0.0);

    // Expanding ripple rings
    float rippleRadius = phase * RIPPLE_SPEED;
    float ripple = 0.0;

    for (float i = 0.0; i < RIPPLE_COUNT; i++) {
        float r = rippleRadius - i * 0.3;
        float ring = sin((dist - r) * 40.0) * exp(-(dist - r) * (dist - r) / (RIPPLE_WIDTH * RIPPLE_WIDTH));
        // Only show rings that have started expanding
        ring *= smoothstep(0.0, 0.1, r);
        ripple += ring;
    }

    // Fade out over time
    float fade = 1.0 - smoothstep(TOTAL_DURATION * 0.5, TOTAL_DURATION, phase);
    // Also fade with distance from origin
    float distFade = exp(-dist * 0.5);
    ripple *= fade * distFade;

    // Distort UVs along the ripple
    vec2 distortUv = uv - dir * ripple * DISTORT_AMOUNT / vec2(aspect, 1.0);
    vec3 result = texture(iChannel0, distortUv).rgb;

    // Subtle blue tint on the ripple peaks
    result += TINT_COLOR * abs(ripple) * TINT_STRENGTH;

    fragColor = vec4(result, base.a);
}
