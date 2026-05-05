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

// ─── Companion creatures ────────────────────────────────────────────
// A little crew that drifts around the cursor — each with their own
// palette, shape, and orbit pattern. All math runs in Y-up space; the
// caller flips Y once before invoking these.
//
// Each `drawX(uv, anchor, base, count)` renders `count` copies of that
// pet, separated by a per-instance time-phase offset so they spread
// around the orbit. count is clamped to MAX_INSTANCES.

const int   MAX_INSTANCES = 10;
const float INSTANCE_PHASE = 2.5;  // time-shift between instances of the same pet

// Pink blob
const vec3 BLOB_COLOR     = vec3(0.957, 0.722, 0.894);
const vec3 BLOB_DEEP      = vec3(0.792, 0.620, 0.882);
const vec3 BLOB_HIGHLIGHT = vec3(1.000, 0.945, 0.965);

// Lavender ghost
const vec3 GHOST_COLOR    = vec3(0.917, 0.910, 0.984);
const vec3 GHOST_DEEP     = vec3(0.706, 0.722, 0.886);
const vec3 GHOST_INK      = vec3(0.118, 0.094, 0.180);

// Yellow star
const vec3 STAR_COLOR     = vec3(0.992, 0.875, 0.541);
const vec3 STAR_DEEP      = vec3(0.937, 0.737, 0.302);
const vec3 STAR_GLINT     = vec3(1.000, 0.980, 0.820);

// Eased anchor in Y-up space (cursor with smooth catch-up on jumps)
vec2 companionAnchor() {
    float follow = clamp((iTime - iTimeCursorChange) / 0.45, 0.0, 1.0);
    follow = 1.0 - pow(1.0 - follow, 3.0);
    vec2 cur  = normPos(iCurrentCursor.xy  + iCurrentCursor.zw  * vec2(0.5, -0.5));
    vec2 prev = normPos(iPreviousCursor.xy + iPreviousCursor.zw * vec2(0.5, -0.5));
    vec2 a = mix(prev, cur, follow);
    return vec2(a.x, -a.y);
}

vec2 rot2(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// HSV → RGB (used for random per-instance hues)
vec3 hsv2rgb(vec3 c) {
    vec3 k = vec3(1.0, 2.0/3.0, 1.0/3.0);
    vec3 p = abs(fract(c.xxx + k) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// Pastel body colour from instance index (golden-ratio hue spread)
vec3 randomBodyCol(int i) {
    float h = fract(float(i) * 0.61803398875);
    return hsv2rgb(vec3(h, 0.45, 0.92));
}

// Sentinel: tint.r < 0 means "pick a random hue per instance"
vec3 resolveTint(vec3 tint, int i) {
    return (tint.r < 0.0) ? randomBodyCol(i) : tint;
}

float blobSDF(vec2 p, vec2 c, float r, float t) {
    vec2 d = p - c;
    float a = atan(d.y, d.x);
    float wobble = sin(a * 3.0 + t * 2.0) * 0.0018
                 + sin(a * 5.0 - t * 1.3) * 0.0010;
    float breath = 1.0 + sin(t * 2.4) * 0.05;
    d.y /= breath;
    return length(d) - (r + wobble);
}

// 5-point star SDF (Inigo Quilez)
float starSDF(vec2 p, float r, float rf) {
    const vec2 k1 = vec2(0.809016994, -0.587785252);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// ─── Pink blob ───────────────────────────────────────────────────────
vec3 drawBlobOne(vec2 uv, vec2 anchor, vec3 base, float t, vec3 bodyCol) {
    vec3 BLOB_COLOR     = bodyCol;
    vec3 BLOB_DEEP      = bodyCol * 0.83;
    vec3 BLOB_HIGHLIGHT = mix(bodyCol, vec3(1.0), 0.6);
    vec2 wander = vec2(
        sin(t * 0.55)        * 0.70 + sin(t * 1.31 + 1.0) * 0.30,
        cos(t * 0.41 + 0.3)  * 0.70 + cos(t * 1.17 + 2.0) * 0.30
    );
    vec2 offset = wander * 0.17;
    offset.y += sin(t * 2.7) * 0.004;
    offset.x += cos(t * 2.3) * 0.003;
    vec2 c = anchor + offset;
    if (length(uv - c) > 0.055) return base;

    float r = 0.028;
    float bodyD = blobSDF(uv, c, r, t);
    float body  = smoothstep(0.0015, -0.0015, bodyD);
    float halo  = exp(max(bodyD, 0.0) * -90.0) * 0.35;

    float hlD = length(uv - (c + vec2(-0.010, 0.010))) - 0.0065;
    float highlight = smoothstep(0.0012, -0.0012, hlD) * 0.7;

    float bp = mod(t, 5.0);
    float blink = clamp(smoothstep(0.0, 0.07, bp) - smoothstep(0.07, 0.16, bp), 0.0, 1.0);
    float eyeY = max(1.0 - blink * 0.92, 0.06);
    vec2 leftEye  = c + vec2(-0.0090, 0.0035);
    vec2 rightEye = c + vec2( 0.0090, 0.0035);
    vec2 le = uv - leftEye;  le.y /= eyeY;
    vec2 re = uv - rightEye; re.y /= eyeY;
    float eyes = smoothstep(0.0008, -0.0008, min(length(le) - 0.003, length(re) - 0.003));
    float sparkles = smoothstep(0.0005, -0.0005,
        min(length(uv - (leftEye  + vec2(0.0010, 0.0012))) - 0.0010,
            length(uv - (rightEye + vec2(0.0010, 0.0012))) - 0.0010));

    vec2 mp = uv - (c + vec2(0.0, -0.0055));
    float smileD = abs(length(mp) - 0.0070) - 0.0010;
    float smile = smoothstep(0.0006, -0.0006, smileD) * smoothstep(0.0, -0.0008, mp.y);

    float blush = smoothstep(0.0035, 0.0, length(uv - (c + vec2(-0.013, -0.001))))
                + smoothstep(0.0035, 0.0, length(uv - (c + vec2( 0.013, -0.001))));
    blush = clamp(blush * 0.45, 0.0, 1.0);

    vec3 col = mix(base, BLOB_COLOR, halo);
    float g = clamp((uv.y - c.y) / r * 0.6 + 0.5, 0.0, 1.0);
    vec3 bodyCol = mix(BLOB_DEEP, BLOB_COLOR, g);
    col = mix(col, bodyCol, body);
    col = mix(col, vec3(1.0, 0.55, 0.65), blush * body * 0.6);
    col = mix(col, BLOB_HIGHLIGHT, highlight * body);
    col = mix(col, vec3(0.10, 0.06, 0.15), eyes * body);
    col = mix(col, vec3(1.0), sparkles * body);
    col = mix(col, vec3(0.18, 0.08, 0.20), smile * body);
    return col;
}

// ─── Lavender ghost ─────────────────────────────────────────────────
// Body = top dome (circle) ∪ rectangle ∪ three wavy bottom bumps.
vec3 drawGhostOne(vec2 uv, vec2 anchor, vec3 base, float t, vec3 bodyCol) {
    vec3 GHOST_COLOR = bodyCol;
    vec3 GHOST_DEEP  = bodyCol * 0.78;
    vec2 wander = vec2(
        sin(t * 0.47 + 1.7) * 0.65 + sin(t * 1.23 + 2.3) * 0.35,
        cos(t * 0.39 + 0.8) * 0.65 + cos(t * 1.09 + 1.1) * 0.35
    );
    // Mirror x so the ghost tends to live on the opposite side from the blob
    vec2 offset = vec2(-wander.x, wander.y) * 0.19;
    offset.y += sin(t * 1.8) * 0.005;
    vec2 c = anchor + offset;
    if (length(uv - c) > 0.055) return base;

    float r = 0.025;
    vec2 d = uv - c;

    float topD = length(d) - r;
    vec2 rectHalf = vec2(r, r * 0.45);
    vec2 rectD = abs(d - vec2(0.0, -r * 0.45)) - rectHalf;
    float rectSDF = length(max(rectD, 0.0)) + min(max(rectD.x, rectD.y), 0.0);

    float bumpR = r * 0.32;
    float bumpY = -r * 0.85;
    vec2 b1 = vec2(-r * 0.66, bumpY + sin(t * 3.0 + 0.0) * r * 0.04);
    vec2 b2 = vec2( 0.0,      bumpY + sin(t * 3.0 + 1.4) * r * 0.04);
    vec2 b3 = vec2( r * 0.66, bumpY + sin(t * 3.0 + 2.8) * r * 0.04);
    float bump1 = length(d - b1) - bumpR;
    float bump2 = length(d - b2) - bumpR;
    float bump3 = length(d - b3) - bumpR;

    float bodyD = min(min(topD, rectSDF), min(min(bump1, bump2), bump3));
    float body  = smoothstep(0.0015, -0.0015, bodyD);
    float halo  = exp(max(bodyD, 0.0) * -100.0) * 0.30;

    float hlD = length(d - vec2(-0.009, 0.009)) - 0.006;
    float highlight = smoothstep(0.0012, -0.0012, hlD) * 0.5;

    // Slightly oval pupils
    vec2 leftEye  = c + vec2(-0.0080, 0.0030);
    vec2 rightEye = c + vec2( 0.0080, 0.0030);
    vec2 le = uv - leftEye;  le.x *= 0.9;
    vec2 re = uv - rightEye; re.x *= 0.9;
    float eyes = smoothstep(0.0008, -0.0008,
        min(length(le) - 0.0028, length(re) - 0.0028));

    // Tiny round "o" mouth
    float mDist  = length(uv - (c + vec2(0.0, -0.0050)));
    float mouth  = smoothstep(0.0006, -0.0006, abs(mDist - 0.0028) - 0.0007);

    vec3 col = mix(base, GHOST_COLOR, halo);
    float g = clamp((uv.y - c.y) / r * 0.5 + 0.5, 0.0, 1.0);
    vec3 bodyCol = mix(GHOST_DEEP, GHOST_COLOR, g);
    col = mix(col, bodyCol, body * 0.92);   // slight transparency
    col = mix(col, vec3(1.0), highlight * body);
    col = mix(col, GHOST_INK, eyes  * body);
    col = mix(col, GHOST_INK, mouth * body);
    return col;
}

// ─── Yellow star ────────────────────────────────────────────────────
vec3 drawStarOne(vec2 uv, vec2 anchor, vec3 base, float t, vec3 bodyCol) {
    vec3 STAR_COLOR = bodyCol;
    vec3 STAR_DEEP  = bodyCol * 0.86;
    vec3 STAR_GLINT = mix(bodyCol, vec3(1.0), 0.65);
    vec2 wander = vec2(
        sin(t * 0.61 + 0.5) * 0.60 + sin(t * 1.43 + 0.9) * 0.40,
        cos(t * 0.53 + 1.2) * 0.60 + cos(t * 1.27 + 2.5) * 0.40
    );
    vec2 offset = wander * 0.16;
    offset.y += cos(t * 2.0) * 0.005;
    vec2 c = anchor + offset;
    if (length(uv - c) > 0.05) return base;

    float r = 0.027;
    vec2 d = uv - c;
    vec2 ds = rot2(d, t * 0.4); // slow spin

    // Rounded 5-petal star — soft, chunky points instead of sharp ones
    float ang = atan(ds.y, ds.x);
    float petal = pow(0.5 + 0.5 * cos(5.0 * ang), 1.4);
    float bodyD = length(ds) - r * (0.70 + 0.30 * petal);
    float body  = smoothstep(0.0015, -0.0015, bodyD);

    // Twinkle pulse
    float twinkle = 0.5 + 0.5 * sin(t * 3.5);
    float halo = exp(max(bodyD, 0.0) * -80.0) * (0.20 + 0.30 * twinkle);

    // Face uses unrotated coords so it stays upright while body spins
    float bp = mod(t, 4.5);
    float blink = clamp(smoothstep(0.0, 0.06, bp) - smoothstep(0.06, 0.14, bp), 0.0, 1.0);
    float eyeY = max(1.0 - blink * 0.92, 0.06);
    vec2 leftEye  = vec2(-0.0060, 0.0010);
    vec2 rightEye = vec2( 0.0060, 0.0010);
    vec2 le = d - leftEye;  le.y /= eyeY;
    vec2 re = d - rightEye; re.y /= eyeY;
    float eyes = smoothstep(0.0006, -0.0006,
        min(length(le) - 0.0020, length(re) - 0.0020));

    vec2 mp = d - vec2(0.0, -0.004);
    float smileD = abs(length(mp) - 0.0050) - 0.0009;
    float smile = smoothstep(0.0005, -0.0005, smileD) * smoothstep(0.0, -0.0008, mp.y);

    // Glint moves with the spinning star
    float glintD = length(ds - vec2(-0.005, 0.012)) - 0.0035;
    float glint = smoothstep(0.0009, -0.0009, glintD) * (0.5 + 0.5 * twinkle);

    vec3 col = mix(base, STAR_COLOR, halo);
    float g = clamp((uv.y - c.y) / r * 0.5 + 0.5, 0.0, 1.0);
    vec3 bodyCol = mix(STAR_DEEP, STAR_COLOR, g);
    col = mix(col, bodyCol, body);
    col = mix(col, STAR_GLINT, glint * body);
    col = mix(col, vec3(0.20, 0.12, 0.05), eyes  * body);
    col = mix(col, vec3(0.25, 0.13, 0.06), smile * body);
    return col;
}

// ─── Toadstool mushroom ─────────────────────────────────────────────
const vec3 MUSHROOM_CAP   = vec3(0.918, 0.388, 0.388);
const vec3 MUSHROOM_DEEP  = vec3(0.788, 0.286, 0.286);
const vec3 MUSHROOM_STEM  = vec3(0.969, 0.929, 0.882);
const vec3 MUSHROOM_SHADE = vec3(0.882, 0.835, 0.776);
const vec3 MUSHROOM_INK   = vec3(0.196, 0.118, 0.094);

vec3 drawMushroomOne(vec2 uv, vec2 anchor, vec3 base, float t, vec3 bodyCol) {
    vec3 MUSHROOM_CAP  = bodyCol;
    vec3 MUSHROOM_DEEP = bodyCol * 0.86;
    // stem/shade/ink stay at their globals (cream stem looks right against any cap)
    vec2 wander = vec2(
        sin(t * 0.49 + 0.3) * 0.65 + sin(t * 1.19 + 1.6) * 0.35,
        cos(t * 0.45 + 2.4) * 0.65 + cos(t * 1.21 + 0.4) * 0.35
    );
    vec2 offset = wander * 0.16;
    vec2 c = anchor + offset;
    if (length(uv - c) > 0.06) return base;

    vec2 d = uv - c;

    // Cap: full rounded dome (top half of a barely-squashed circle)
    vec2 capD = d - vec2(0.0, 0.003);
    capD.y *= 0.92;
    float capSDF = length(capD) - 0.026;
    capSDF = max(capSDF, -d.y - 0.003);

    // Stem: pill shape (very rounded, narrower than the cap)
    vec2 stemRect = abs(d - vec2(0.0, -0.014)) - vec2(0.005, 0.008);
    float stemSDF = length(max(stemRect, 0.0)) + min(max(stemRect.x, stemRect.y), 0.0) - 0.008;

    float bodyD = min(capSDF, stemSDF);
    float halo  = exp(max(bodyD, 0.0) * -100.0) * 0.25;

    // Plump white polka-dot spots on cap
    float spot1 = length(d - vec2(-0.012, 0.012)) - 0.0036;
    float spot2 = length(d - vec2( 0.013, 0.008)) - 0.0030;
    float spot3 = length(d - vec2( 0.000, 0.020)) - 0.0034;
    float spots = smoothstep(0.0008, -0.0008, min(min(spot1, spot2), spot3));

    float capMask  = smoothstep(0.001, -0.001, capSDF);
    float stemMask = smoothstep(0.001, -0.001, stemSDF);

    // Face on the stem
    float bp = mod(t, 5.0);
    float blink = clamp(smoothstep(0.0, 0.07, bp) - smoothstep(0.07, 0.16, bp), 0.0, 1.0);
    float eyeY = max(1.0 - blink * 0.92, 0.06);
    vec2 leftEye  = c + vec2(-0.0050, -0.013);
    vec2 rightEye = c + vec2( 0.0050, -0.013);
    vec2 le = uv - leftEye;  le.y /= eyeY;
    vec2 re = uv - rightEye; re.y /= eyeY;
    float eyes = smoothstep(0.0006, -0.0006,
        min(length(le) - 0.0020, length(re) - 0.0020));

    vec2 mp = uv - (c + vec2(0.0, -0.018));
    float smileD = abs(length(mp) - 0.0030) - 0.0006;
    float smile = smoothstep(0.0005, -0.0005, smileD) * smoothstep(0.0, -0.0008, mp.y);

    float blush = smoothstep(0.0028, 0.0, length(uv - (c + vec2(-0.008, -0.013))))
                + smoothstep(0.0028, 0.0, length(uv - (c + vec2( 0.008, -0.013))));
    blush = clamp(blush * 0.5, 0.0, 1.0);

    vec3 col = mix(base, MUSHROOM_CAP, halo);

    // Cap (red gradient)
    float gc = clamp((uv.y - c.y - 0.003) / 0.026 * 0.6 + 0.5, 0.0, 1.0);
    col = mix(col, mix(MUSHROOM_DEEP, MUSHROOM_CAP, gc), capMask);

    // Stem (cream gradient)
    float gs = clamp((uv.y - c.y + 0.014) / 0.011 * 0.5 + 0.5, 0.0, 1.0);
    col = mix(col, mix(MUSHROOM_SHADE, MUSHROOM_STEM, gs), stemMask);

    col = mix(col, vec3(1.00, 0.97, 0.93), spots * capMask);
    col = mix(col, vec3(1.00, 0.62, 0.62), blush * stemMask * 0.7);
    col = mix(col, MUSHROOM_INK, eyes  * stemMask);
    col = mix(col, MUSHROOM_INK, smile * stemMask);
    return col;
}

// ─── Puffy cloud ────────────────────────────────────────────────────
const vec3 CLOUD_COLOR = vec3(0.957, 0.969, 0.992);
const vec3 CLOUD_SHADE = vec3(0.788, 0.831, 0.902);
const vec3 CLOUD_INK   = vec3(0.310, 0.353, 0.450);

vec3 drawCloudOne(vec2 uv, vec2 anchor, vec3 base, float t, vec3 bodyCol) {
    vec3 CLOUD_COLOR = bodyCol;
    vec3 CLOUD_SHADE = bodyCol * 0.82;
    vec2 wander = vec2(
        sin(t * 0.43 + 1.1) * 0.70 + sin(t * 1.09 + 2.5) * 0.30,
        cos(t * 0.37 + 0.6) * 0.70 + cos(t * 1.31 + 1.7) * 0.30
    );
    vec2 offset = wander * 0.17;
    offset.y += sin(t * 1.5) * 0.003;
    vec2 c = anchor + offset;
    if (length(uv - c) > 0.07) return base;

    vec2 d = uv - c;
    float r = 0.026;

    // Five overlapping puffs
    float c1 = length(d - vec2(-r * 0.65,  r * 0.10)) - r * 0.55;
    float c2 = length(d - vec2( 0.0,       r * 0.30)) - r * 0.65;
    float c3 = length(d - vec2( r * 0.65,  r * 0.05)) - r * 0.55;
    float c4 = length(d - vec2(-r * 0.30, -r * 0.20)) - r * 0.50;
    float c5 = length(d - vec2( r * 0.35, -r * 0.15)) - r * 0.50;
    float bodyD = min(min(c1, c2), min(min(c3, c4), c5));
    float body  = smoothstep(0.0015, -0.0015, bodyD);
    float halo  = exp(max(bodyD, 0.0) * -80.0) * 0.25;

    // Eyes
    float bp = mod(t, 6.0);
    float blink = clamp(smoothstep(0.0, 0.08, bp) - smoothstep(0.08, 0.18, bp), 0.0, 1.0);
    float eyeY = max(1.0 - blink * 0.92, 0.06);
    vec2 leftEye  = c + vec2(-0.0080, 0.0050);
    vec2 rightEye = c + vec2( 0.0080, 0.0050);
    vec2 le = uv - leftEye;  le.y /= eyeY;
    vec2 re = uv - rightEye; re.y /= eyeY;
    float eyes = smoothstep(0.0006, -0.0006,
        min(length(le) - 0.0022, length(re) - 0.0022));

    vec2 mp = uv - (c + vec2(0.0, -0.001));
    float smileD = abs(length(mp) - 0.0050) - 0.0008;
    float smile = smoothstep(0.0006, -0.0006, smileD) * smoothstep(0.0, -0.0008, mp.y);

    float blush = smoothstep(0.0030, 0.0, length(uv - (c + vec2(-0.013, 0.001))))
                + smoothstep(0.0030, 0.0, length(uv - (c + vec2( 0.013, 0.001))));
    blush = clamp(blush * 0.4, 0.0, 1.0);

    vec3 col = mix(base, CLOUD_COLOR, halo);
    float g = clamp((uv.y - c.y) / r * 0.6 + 0.5, 0.0, 1.0);
    vec3 bodyCol = mix(CLOUD_SHADE, CLOUD_COLOR, g);
    col = mix(col, bodyCol, body);
    col = mix(col, vec3(1.0, 0.70, 0.75), blush * body * 0.6);
    col = mix(col, CLOUD_INK, eyes  * body);
    col = mix(col, CLOUD_INK, smile * body);
    return col;
}

// ─── Glowing fairy ──────────────────────────────────────────────────
// Tiny luminous body with four flapping wings and orbiting sparkles.
const vec3 FAIRY_GLOW  = vec3(0.957, 0.812, 0.957);
const vec3 FAIRY_CORE  = vec3(1.000, 0.945, 0.980);
const vec3 FAIRY_WING  = vec3(0.918, 0.890, 1.000);
const vec3 FAIRY_SPARK = vec3(1.000, 0.920, 0.700);

vec3 drawFairyOne(vec2 uv, vec2 anchor, vec3 base, float t, vec3 bodyCol) {
    vec3 FAIRY_GLOW = bodyCol;
    vec3 FAIRY_CORE = mix(bodyCol, vec3(1.0), 0.85);
    vec3 FAIRY_WING = mix(bodyCol, vec3(1.0), 0.55);
    // golden spark stays fixed for that fairy-dust feel
    vec2 wander = vec2(
        sin(t * 0.71 + 0.3) * 0.60 + sin(t * 1.53 + 1.4) * 0.40,
        cos(t * 0.67 + 1.8) * 0.60 + cos(t * 1.41 + 2.1) * 0.40
    );
    vec2 offset = wander * 0.18;
    offset.y += sin(t * 8.0) * 0.0012;  // hummingbird flutter
    vec2 c = anchor + offset;
    if (length(uv - c) > 0.055) return base;

    vec2 d = uv - c;

    // Soft outer glow
    float gd = length(d);
    float glow = exp(-gd * gd / 0.00080) * 0.65;

    // Bright body core
    float bodyD = length(d) - 0.0090;
    float body  = smoothstep(0.0010, -0.0010, bodyD);

    // Four flapping leaf-shaped wings
    float flap = 1.0 + sin(t * 22.0) * 0.30;
    vec2 wTL = rot2(d - vec2(-0.008,  0.005),  0.6); wTL.x *= 1.6 / flap;
    vec2 wTR = rot2(d - vec2( 0.008,  0.005), -0.6); wTR.x *= 1.6 / flap;
    vec2 wBL = rot2(d - vec2(-0.007, -0.005), -0.4); wBL.x *= 1.8 / flap;
    vec2 wBR = rot2(d - vec2( 0.007, -0.005),  0.4); wBR.x *= 1.8 / flap;
    float wingsD = min(min(length(wTL) - 0.0080, length(wTR) - 0.0080),
                       min(length(wBL) - 0.0065, length(wBR) - 0.0065));
    float wings  = smoothstep(0.0008, -0.0008, wingsD);

    // Four orbiting sparkles
    float sa = t * 1.5;
    float sR = 0.018 + 0.005 * sin(t * 2.0);
    vec2 sp1 = vec2(cos(sa + 0.0),  sin(sa + 0.0))  * sR;
    vec2 sp2 = vec2(cos(sa + 1.6),  sin(sa + 1.6))  * (sR * 0.85);
    vec2 sp3 = vec2(cos(sa + 3.2),  sin(sa + 3.2))  * (sR * 1.10);
    vec2 sp4 = vec2(cos(sa + 4.8),  sin(sa + 4.8))  * (sR * 0.95);
    float sd = min(min(length(d - sp1), length(d - sp2)),
                   min(length(d - sp3), length(d - sp4))) - 0.0009;
    float sparkles = smoothstep(0.0005, -0.0005, sd) * (0.6 + 0.4 * sin(t * 4.0));
    sparkles = clamp(sparkles, 0.0, 1.0);

    vec3 col = base;
    col = mix(col, FAIRY_GLOW,  glow);
    col = mix(col, FAIRY_WING,  wings * 0.55);   // translucent wings
    col = mix(col, FAIRY_CORE,  body);
    col = mix(col, FAIRY_SPARK, sparkles);
    return col;
}

// ─── Little bird ────────────────────────────────────────────────────
// Sky-blue songbird, always facing right; flapping wing and bobbing.
const vec3 BIRD_COLOR = vec3(0.553, 0.812, 0.929);
const vec3 BIRD_DEEP  = vec3(0.396, 0.612, 0.769);
const vec3 BIRD_BELLY = vec3(0.953, 0.965, 0.984);
const vec3 BIRD_BEAK  = vec3(0.957, 0.690, 0.310);
const vec3 BIRD_INK   = vec3(0.094, 0.094, 0.156);

vec3 drawBirdOne(vec2 uv, vec2 anchor, vec3 base, float t, vec3 bodyCol) {
    vec3 BIRD_COLOR = bodyCol;
    vec3 BIRD_DEEP  = bodyCol * 0.72;
    vec3 BIRD_BELLY = mix(bodyCol, vec3(1.0), 0.85);
    // beak (orange) and ink stay at their globals
    vec2 wander = vec2(
        sin(t * 0.61 + 1.7) * 0.65 + sin(t * 1.37 + 0.5) * 0.35,
        cos(t * 0.55 + 0.9) * 0.65 + cos(t * 1.29 + 2.3) * 0.35
    );
    vec2 offset = wander * 0.18;
    offset.y += sin(t * 4.0) * 0.003;  // flap-induced bob
    vec2 c = anchor + offset;
    if (length(uv - c) > 0.06) return base;

    vec2 d = uv - c;

    // Body: tilted egg shape
    vec2 bd = rot2(d, 0.15);
    bd.y *= 1.5;
    float bodyD = length(bd) - 0.018;

    // Head: smaller circle in front
    float headD = length(d - vec2(0.013, 0.005)) - 0.011;

    // Tail: rotated thin ellipse trailing back-left
    vec2 td = rot2(d - vec2(-0.018, 0.000), -0.2);
    td.y *= 2.5;
    float tailD = length(td) - 0.004;

    // Beak: small horizontal sliver in front of head
    vec2 bkd = d - vec2(0.022, 0.005);
    bkd.y *= 2.5;
    float beakD = length(bkd) - 0.0035;

    float bodyAllD = min(min(bodyD, headD), tailD);
    float body  = smoothstep(0.0015, -0.0015, bodyAllD);
    float beak  = smoothstep(0.0008, -0.0008, beakD);
    float halo  = exp(max(bodyAllD, 0.0) * -100.0) * 0.25;

    // Light belly underside
    float bellyD = length(d - vec2(0.000, -0.005)) - 0.012;
    float belly  = smoothstep(0.0010, -0.0010, bellyD);

    // Wing: tilted oval that vertically flaps
    float flap = 1.0 + sin(t * 8.0) * 0.40;
    vec2 wd = rot2(d - vec2(-0.002, 0.002), -0.1);
    wd.y *= 1.8 / flap;
    float wingD = length(wd) - 0.009;
    float wing  = smoothstep(0.0010, -0.0010, wingD);

    // Single eye (dot on head)
    float eye = smoothstep(0.0005, -0.0005,
        length(uv - (c + vec2(0.016, 0.008))) - 0.0015);

    vec3 col = mix(base, BIRD_COLOR, halo);
    float g = clamp((uv.y - c.y) / 0.018 * 0.5 + 0.5, 0.0, 1.0);
    vec3 bodyCol = mix(BIRD_DEEP, BIRD_COLOR, g);
    col = mix(col, bodyCol, body);

    // Belly only inside the main body
    float bodyMask = smoothstep(0.001, -0.001, bodyD);
    col = mix(col, BIRD_BELLY, belly * bodyMask * 0.7);

    // Wing slightly darker, masked to body
    col = mix(col, BIRD_DEEP, wing * bodyMask);

    // Beak
    col = mix(col, BIRD_BEAK, beak);

    // Eye on head
    float headMask = smoothstep(0.001, -0.001, headD);
    col = mix(col, BIRD_INK, eye * headMask);
    return col;
}

// ─── Multi-instance wrappers ────────────────────────────────────────
// Each wrapper renders `count` copies of the pet (clamped to MAX_INSTANCES),
// staggered in time-phase so they spread out along the orbit.

vec3 drawBlob(vec2 uv, vec2 anchor, vec3 base, int count, vec3 tint) {
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (i >= count) break;
        base = drawBlobOne(uv, anchor, base, iTime + float(i) * INSTANCE_PHASE, resolveTint(tint, i));
    }
    return base;
}
vec3 drawGhost(vec2 uv, vec2 anchor, vec3 base, int count, vec3 tint) {
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (i >= count) break;
        base = drawGhostOne(uv, anchor, base, iTime + 7.3 + float(i) * INSTANCE_PHASE, resolveTint(tint, i));
    }
    return base;
}
vec3 drawStar(vec2 uv, vec2 anchor, vec3 base, int count, vec3 tint) {
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (i >= count) break;
        base = drawStarOne(uv, anchor, base, iTime + 13.7 + float(i) * INSTANCE_PHASE, resolveTint(tint, i));
    }
    return base;
}
vec3 drawMushroom(vec2 uv, vec2 anchor, vec3 base, int count, vec3 tint) {
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (i >= count) break;
        base = drawMushroomOne(uv, anchor, base, iTime + 25.5 + float(i) * INSTANCE_PHASE, resolveTint(tint, i));
    }
    return base;
}
vec3 drawCloud(vec2 uv, vec2 anchor, vec3 base, int count, vec3 tint) {
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (i >= count) break;
        base = drawCloudOne(uv, anchor, base, iTime + 31.7 + float(i) * INSTANCE_PHASE, resolveTint(tint, i));
    }
    return base;
}
vec3 drawFairy(vec2 uv, vec2 anchor, vec3 base, int count, vec3 tint) {
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (i >= count) break;
        base = drawFairyOne(uv, anchor, base, iTime + 43.2 + float(i) * INSTANCE_PHASE, resolveTint(tint, i));
    }
    return base;
}
vec3 drawBird(vec2 uv, vec2 anchor, vec3 base, int count, vec3 tint) {
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (i >= count) break;
        base = drawBirdOne(uv, anchor, base, iTime + 49.7 + float(i) * INSTANCE_PHASE, resolveTint(tint, i));
    }
    return base;
}

// ─── Main ────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    vec2 vu = normPos(fragCoord);

    vec4 curRaw  = iCurrentCursor;
    vec4 prevRaw = iPreviousCursor;

    vec2 cursorCenter = normPos(curRaw.xy  + curRaw.zw  * vec2(0.5, -0.5));
    vec2 prevCenter   = normPos(prevRaw.xy + prevRaw.zw * vec2(0.5, -0.5));
    vec2 cursorSize   = normSize(curRaw.zw);

    // Warp streak only fires while a cursor change animation is active
    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float dist = distance(curRaw.xy, prevRaw.xy);

    if (progress < 1.0 && dist >= 0.5) {
        float intensity = 1.0;
        float warpProgress = progress;
        if (isTypingOrDeleting(curRaw, prevRaw)) {
            intensity = 0.7;
            warpProgress = clamp((iTime - iTimeCursorChange) / (DURATION * 0.5), 0.0, 1.0);
        }
        fragColor = warpEffect(vu, cursorCenter, prevCenter, cursorSize, warpProgress, fragColor, intensity);
    }

    // ─── Companions ─── pick any combination by uncommenting the lines below.
    // Each creature drifts independently around the cursor on its own orbit.
    vec2 anchor = companionAnchor();
    vec2 vuY    = vec2(vu.x, -vu.y);  // Y-up space for the creatures
    vec3 col    = fragColor.rgb;
    col = drawBlob    (vuY, anchor, col, 0, vec3(-1.0, 0.0, 0.0));  // pink blob       — count 0..10
    col = drawGhost   (vuY, anchor, col, 0, vec3(-1.0, 0.0, 0.0));  // lavender ghost  — count 0..10
    col = drawStar    (vuY, anchor, col, 0, vec3(-1.0, 0.0, 0.0));  // yellow star     — count 0..10
    col = drawMushroom(vuY, anchor, col, 0, vec3(-1.0, 0.0, 0.0));  // red toadstool   — count 0..10
    col = drawCloud   (vuY, anchor, col, 0, vec3(-1.0, 0.0, 0.0));  // puffy cloud     — count 0..10
    col = drawFairy   (vuY, anchor, col, 0, vec3(-1.0, 0.0, 0.0));  // glowing fairy   — count 0..10
    col = drawBird    (vuY, anchor, col, 0, vec3(-1.0, 0.0, 0.0));  // sky-blue bird   — count 0..10
    fragColor = vec4(col, fragColor.a);
}
