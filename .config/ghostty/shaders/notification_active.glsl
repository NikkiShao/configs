const float START_TIME = 261118.891;
// notification_pulse.glsl — EMP blast: flash, scanlines, flicker, settle

// ─── Tunables ────────────────────────────────────────────────────────
const float FLASH_DURATION  = 0.2;
const float FLASH_INTENSITY = 0.18;
const float SCANLINE_SPEED  = 5.0;
const float SCANLINE_THICK  = 200.0;
const float SCANLINE_ALPHA  = 0.05;
const float CHROMA_MAX      = 0.005;
const float FLICKER_SPEED   = 18.0;
const float FLICKER_AMOUNT  = 0.025;
const float NOISE_AMOUNT    = 0.035;
const float TOTAL_DURATION  = 2.0;

const vec3 FLASH_COLOR = vec3(0.537, 0.706, 0.980);  // catppuccin blue tint #89b4fa

// ─── Noise ───────────────────────────────────────────────────────────
float hash(float n) { return fract(sin(n) * 43758.5453); }
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

    // START_TIME is injected by the hook script
    float phase = clamp(iTime - START_TIME, 0.0, TOTAL_DURATION);

    float recovery = exp(-phase * 1.8) * smoothstep(0.0, 0.05, phase);

    // === 1. Flash ===
    float flash = smoothstep(FLASH_DURATION, 0.0, phase) * FLASH_INTENSITY;
    vec3 flashCol = mix(vec3(1.0), FLASH_COLOR, 0.3);

    // === 2. Chromatic aberration ===
    float chroma = CHROMA_MAX * recovery;
    float r = texture(iChannel0, uv + vec2(chroma, 0.0)).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - vec2(chroma, 0.0)).b;
    vec3 shifted = vec3(r, g, b);

    // === 3. Scanlines ===
    float scanY = uv.y * SCANLINE_THICK - phase * SCANLINE_SPEED;
    float scanline = sin(scanY * 6.2831853) * 0.5 + 0.5;
    scanline = pow(scanline, 3.0);
    float scanAlpha = SCANLINE_ALPHA * recovery;

    float rollBar = smoothstep(0.0, 0.1, sin((uv.y - phase * 0.8) * 4.0));
    float rollAlpha = 0.1 * recovery * rollBar;

    // === 4. Flicker ===
    float flicker = (hash(floor(phase * FLICKER_SPEED)) * 2.0 - 1.0) * FLICKER_AMOUNT * recovery;

    // === 5. Grain ===
    float grain = (hash2(uv * iResolution.xy + vec2(phase * 1000.0)) - 0.5) * NOISE_AMOUNT * recovery;

    // === 6. Jitter ===
    float jitter = (hash(floor(uv.y * 80.0) + floor(phase * 30.0)) - 0.5) * 0.005 * recovery;
    vec2 jitterUv = vec2(uv.x + jitter, uv.y);
    vec3 jittered = texture(iChannel0, jitterUv).rgb;

    // Combine
    vec3 result = mix(shifted, jittered, recovery * 0.5);
    result -= scanline * scanAlpha;
    result -= rollAlpha;
    result += flicker;
    result += grain;
    result = mix(result, flashCol, flash);

    vec2 vc = uv - 0.5;
    float vignette = dot(vc, vc) * 1.5 * recovery;
    result -= vignette * 0.3;

    fragColor = vec4(result, base.a);
}
