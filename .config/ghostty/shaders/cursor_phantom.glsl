// cursor_phantom.glsl — Warp-tunnel streak on all cursor movement

// ─── Tunables ────────────────────────────────────────────────────────
const float DURATION        = 0.25;
const float MOVE_INTENSITY  = 1.0;
const vec3 WARP_COLOR       = vec3(0.537, 0.706, 0.980);  // catppuccin mocha blue #89b4fa
const vec3 WARP_ACCENT      = vec3(0.361, 0.514, 0.882);  // darker shade of mocha blue

// ─── Helpers ─────────────────────────────────────────────────────────
vec2 normPos(vec2 value) {
    return (value * 2.0 - iResolution.xy) / iResolution.y;
}
vec2 normSize(vec2 value) {
    return value * 2.0 / iResolution.y;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float getSdfRect(vec2 p, vec2 center, vec2 half_size) {
    vec2 d = abs(p - center) - half_size;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float easeOut(float t) { return 1.0 - pow(1.0 - t, 3.0); }

// ─── Action detection ────────────────────────────────────────────────
bool isTypingOrDeleting(vec4 cur, vec4 prev) {
    vec2 delta = cur.xy - prev.xy;
    float dx = delta.x / max(cur.z, 0.001);
    float dy = abs(delta.y) / max(cur.w, 0.001);
    if (dy < 1.5 && dx > 0.3) return true;
    if (dy < 1.5 && dx < -0.3) return true;
    return false;
}

// ─── Warp-tunnel streak ─────────────────────────────────────────────
vec4 warpEffect(vec2 uv, vec2 cursorCenter, vec2 prevCenter, vec2 cursorSize, float progress, vec4 base, float intensity) {
    float t = progress;
    float invT = 1.0 - t;

    vec2 moveDir = cursorCenter - prevCenter;
    float moveDist = length(moveDir);
    if (moveDist < 0.001) return base;
    vec2 moveNorm = moveDir / moveDist;
    vec2 movePerp = vec2(-moveNorm.y, moveNorm.x);

    vec2 toFrag = uv - prevCenter;
    float along = dot(toFrag, moveNorm);
    float perp = dot(toFrag, movePerp);

    // Warp trail — tapered streak from prev to current
    float trailHead = moveDist * easeOut(t);
    float trailTail = moveDist * easeOut(t) * t;
    float inTrail = smoothstep(trailTail - 0.01, trailTail + 0.005, along)
                  * smoothstep(trailHead + 0.005, trailHead - 0.01, along);

    // Taper width: wide at prev, narrow at current (narrower when muted)
    float taperT = clamp((along - trailTail) / max(trailHead - trailTail, 0.001), 0.0, 1.0);
    float width = mix(0.025, 0.003, taperT) * MOVE_INTENSITY * intensity;

    // Sharp streak mask (no waviness)
    float streakMask = smoothstep(width, width * 0.3, abs(perp)) * inTrail * invT;

    // Warp glow at cursor leading edge (tighter and dimmer when muted)
    float glowRadius = 0.0006 * intensity;
    float headDist = length(uv - (prevCenter + moveNorm * trailHead));
    float headGlow = exp(-headDist * headDist / (glowRadius * invT + 0.00001)) * invT * intensity;

    // Afterimage at previous position (smaller and dimmer when muted)
    float ghostDist = length(uv - prevCenter);
    float ghost = exp(-ghostDist * ghostDist / (0.0008 * intensity)) * invT * invT * 0.5 * intensity;
    float ghostCursor = smoothstep(0.002, 0.0, getSdfRect(uv, prevCenter, cursorSize * 0.5)) * invT * invT * 0.3 * intensity;

    // Composite
    vec3 warpCol = mix(WARP_ACCENT, WARP_COLOR, taperT);
    float totalAlpha = clamp(streakMask * 0.7 + headGlow * 0.8 + ghost + ghostCursor, 0.0, 1.0) * MOVE_INTENSITY;

    return vec4(mix(base.rgb, warpCol, totalAlpha), base.a);
}

// ─── Main ────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    vec2 vu = normPos(fragCoord);

    vec4 curRaw = iCurrentCursor;
    vec4 prevRaw = iPreviousCursor;

    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (progress >= 1.0) return;

    // Skip if cursor barely moved
    float dist = distance(curRaw.xy, prevRaw.xy);
    if (dist < 0.5) return;

    vec2 cursorCenter = normPos(curRaw.xy + curRaw.zw * vec2(0.5, -0.5));
    vec2 prevCenter   = normPos(prevRaw.xy + prevRaw.zw * vec2(0.5, -0.5));
    vec2 cursorSize   = normSize(curRaw.zw);

    // Mute effect for single-character typing/deleting
    float intensity = 1.0;
    if (isTypingOrDeleting(curRaw, prevRaw)) {
        intensity = 0.7;
        progress = clamp((iTime - iTimeCursorChange) / (DURATION * 0.5), 0.0, 1.0);
    }

    fragColor = warpEffect(vu, cursorCenter, prevCenter, cursorSize, progress, fragColor, intensity);
}
