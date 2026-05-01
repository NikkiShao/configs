// notification_flashbang.glsl — Flashbang: blinding white flash → slow recovery

// ─── Tunables ────────────────────────────────────────────────────────
const float BLIND_PEAK     = 0.08;   // seconds of pure white
const float FADE_RATE      = 2.5;    // exponential decay speed after peak
const float BLOOM_RADIUS   = 0.012;  // glow bleed around bright areas
const float BLOOM_STRENGTH = 0.6;    // bloom mix intensity
const float CHROMA_MAX     = 0.008;  // chromatic aberration at peak
const float GRAIN_AMOUNT   = 0.08;   // film grain while recovering
const float TINT_STRENGTH  = 0.15;   // warm afterimage tint
const float TOTAL_DURATION = 3.0;    // full cycle length

const vec3 AFTERIMAGE_TINT = vec3(1.0, 0.85, 0.6);  // warm amber afterimage

// ─── Helpers ─────────────────────────────────────────────────────────
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// cheap 5-tap bloom
vec3 bloom(vec2 uv, float radius) {
    vec3 sum = texture(iChannel0, uv).rgb * 0.4;
    sum += texture(iChannel0, uv + vec2( radius,  0.0)).rgb * 0.15;
    sum += texture(iChannel0, uv + vec2(-radius,  0.0)).rgb * 0.15;
    sum += texture(iChannel0, uv + vec2(0.0,  radius)).rgb * 0.15;
    sum += texture(iChannel0, uv + vec2(0.0, -radius)).rgb * 0.15;
    return sum;
}

// ─── Main ────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    float t = mod(iTime, TOTAL_DURATION);

    // Phase 1: blinding white
    float blind = smoothstep(BLIND_PEAK, 0.0, t);

    // Phase 2: recovery — exponential fade from white
    float recovery = exp(-(t - BLIND_PEAK) * FADE_RATE) * step(BLIND_PEAK, t);

    // Total flash intensity (1.0 = pure white, 0.0 = normal)
    float intensity = max(blind, recovery);

    // Chromatic aberration — strongest at peak, fades with recovery
    float chroma = CHROMA_MAX * intensity;
    float r = texture(iChannel0, uv + vec2(chroma, 0.0)).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - vec2(chroma, 0.0)).b;
    vec3 shifted = vec3(r, g, b);

    // Bloom — overexposed glow bleeding
    vec3 bloomed = bloom(uv, BLOOM_RADIUS * intensity);
    vec3 scene = mix(shifted, bloomed, BLOOM_STRENGTH * intensity);

    // Warm afterimage tint during recovery
    scene = mix(scene, scene * AFTERIMAGE_TINT, TINT_STRENGTH * recovery);

    // Film grain during recovery
    float grain = (hash2(uv * iResolution.xy + vec2(t * 1000.0)) - 0.5) * GRAIN_AMOUNT * recovery;
    scene += grain;

    // Whiteout blend
    scene = mix(scene, vec3(1.0), intensity * 0.95);

    // Vignette — slight darkening at edges during recovery (eyes adjusting)
    vec2 vc = uv - 0.5;
    float vignette = dot(vc, vc) * 2.0 * recovery;
    scene -= vignette * 0.2;

    fragColor = vec4(scene, base.a);
}
