// notification_shimmer.glsl — Bottom bar shimmer: green progress sweep left to right

// ─── Tunables ────────────────────────────────────────────────────────
const float BAR_HEIGHT      = 0.035;        // how tall the effect is (fraction of screen)
const float SWEEP_DURATION  = 0.8;          // time to sweep left to right
const float DISTORT_AMOUNT  = 0.003;        // heat shimmer distortion
const float WAVE_FREQ       = 40.0;         // waviness frequency
const float WAVE_SPEED      = 8.0;          // wave animation speed
const float TINT_STRENGTH   = 0.12;         // green tint opacity
const float EDGE_SOFTNESS   = 0.008;        // soft edge on top of bar

const vec3 GREEN = vec3(0.651, 0.890, 0.631);  // catppuccin green #a6e3a1

// ─── Noise ───────────────────────────────────────────────────────────
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
        mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

// ─── Main ────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float t = iTime;
    float phase = mod(t, SWEEP_DURATION) / SWEEP_DURATION;

    // Only affect the bottom strip
    float barMask = smoothstep(BAR_HEIGHT + EDGE_SOFTNESS, BAR_HEIGHT - EDGE_SOFTNESS, uv.y);
    if (barMask < 0.001) {
        fragColor = base;
        return;
    }

    // Progress: sweep from left to right
    float progress = phase;
    float sweepMask = smoothstep(progress - 0.05, progress, uv.x) * (1.0 - smoothstep(progress, progress + 0.05, uv.x));
    float fillMask = smoothstep(progress, progress - 0.02, uv.x);

    // Heat shimmer distortion — wavy displacement
    float wave = sin(uv.x * WAVE_FREQ + t * WAVE_SPEED) * 0.5
               + sin(uv.x * WAVE_FREQ * 1.7 - t * WAVE_SPEED * 0.8) * 0.3
               + noise(vec2(uv.x * 20.0, t * 3.0)) * 0.2;
    float distort = wave * DISTORT_AMOUNT * barMask * fillMask;

    vec2 distUv = vec2(uv.x, uv.y + distort);
    vec3 result = texture(iChannel0, distUv).rgb;

    // Green tint — stronger at the sweep edge, subtle in the filled area
    float tint = fillMask * 0.4 + sweepMask * 1.0;
    tint *= barMask * TINT_STRENGTH;

    // Slight shimmer variation in the filled area
    float shimmer = noise(vec2(uv.x * 15.0 - t * 2.0, uv.y * 50.0));
    tint *= (0.7 + 0.3 * shimmer);

    result = mix(result, GREEN, tint);

    // Bright leading edge
    result += GREEN * sweepMask * barMask * 0.15;

    fragColor = vec4(result, base.a);
}
