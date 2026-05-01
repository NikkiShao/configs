// cursor_chaos.glsl — Action-reactive cursor effects v4
//
// ALL actions get screen shake. Effects:
//   - Typing:   lightning bolts striking nearby characters + electric glow
//   - Deleting: swarm of small scattered explosions across deleted region
//   - Movement: warp streak + heavy shake + particles

// ─── Tunables ────────────────────────────────────────────────────────
const float DURATION          = 0.5;
const float SHAKE_DURATION    = 0.35;
const float SHAKE_BASE        = 5.0;
const float SHAKE_MOVE_MULT   = 2.5;
const float SHAKE_TYPE_MULT   = 1.0;
const float SHAKE_DEL_MULT    = 1.8;
const float MOVE_INTENSITY    = 1.0;

// Colors — Catppuccin Mocha
const vec3 BOLT_WHITE   = vec3(0.90, 0.95, 1.00);
const vec3 BOLT_CORE    = vec3(0.537, 0.706, 0.980);  // blue #89b4fa
const vec3 BOLT_GLOW    = vec3(0.455, 0.816, 0.992);  // sapphire #74c7ec
const vec3 BOLT_FAINT   = vec3(0.804, 0.518, 0.976);  // mauve #cba6f7
const vec3 BOOM_CORE    = vec3(1.00, 0.95, 0.75);   // bright yellow-white
const vec3 BOOM_HOT     = vec3(1.00, 0.65, 0.20);   // orange
const vec3 BOOM_EMBER   = vec3(0.984, 0.702, 0.533); // peach #fab387
const vec3 WARP_COLOR   = vec3(0.537, 0.706, 0.980);
const vec3 WARP_ACCENT  = vec3(0.455, 0.816, 0.992);

// ─── Helpers ─────────────────────────────────────────────────────────
vec2 normPos(vec2 v) { return (v * 2.0 - iResolution.xy) / iResolution.y; }
vec2 normSize(vec2 v) { return v * 2.0 / iResolution.y; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
               mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}

float getSdfRect(vec2 p, vec2 c, vec2 h) {
    vec2 d = abs(p - c) - h;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float easeOut(float t) { return 1.0 - pow(1.0 - t, 3.0); }

// ─── Screen shake ────────────────────────────────────────────────────
vec2 calcShake(float shakeProgress, float mult) {
    float decay = (1.0 - shakeProgress);
    decay *= decay;
    float str = SHAKE_BASE * mult;
    float sx = sin(iTime * 95.0) * str * decay
             + sin(iTime * 170.0) * str * decay * 0.3;
    float sy = cos(iTime * 80.0) * str * decay * 0.7
             + cos(iTime * 140.0) * str * decay * 0.2;
    return vec2(sx, sy) / iResolution.xy;
}

// ─── Action detection ────────────────────────────────────────────────
int detectAction(vec4 cur, vec4 prev) {
    vec2 delta = cur.xy - prev.xy;
    float dx = delta.x / max(cur.z, 0.001);
    float dy = abs(delta.y) / max(cur.w, 0.001);
    if (dy < 1.5 && dx > 0.3) return 0;
    if (dy < 1.5 && dx < -0.3) return 1;
    return 2;
}

// ─── Lightning bolt SDF (jagged line between two points) ─────────────
// Returns intensity of a bolt between points a and b
float boltLine(vec2 p, vec2 a, vec2 b, float seed, float time) {
    vec2 dir = b - a;
    float len = length(dir);
    if (len < 0.001) return 0.0;
    vec2 n = dir / len;
    vec2 perp = vec2(-n.y, n.x);

    // Project point onto bolt axis
    float along = dot(p - a, n);
    float perpD = dot(p - a, perp);
    float t_along = along / len;

    // Outside the bolt range
    if (t_along < -0.05 || t_along > 1.05) return 0.0;

    // Jagged displacement — multiple noise octaves for zigzag look
    float displacement = 0.0;
    displacement += noise(vec2(t_along * 15.0 + seed * 100.0, time * 8.0)) * 0.012;
    displacement += noise(vec2(t_along * 30.0 + seed * 77.0, time * 12.0)) * 0.006;
    displacement += noise(vec2(t_along * 60.0 + seed * 33.0, time * 16.0)) * 0.003;
    displacement -= 0.0105; // center it

    // Bolt thickness — thicker at start, thinner at end
    float thickness = mix(0.004, 0.001, t_along);

    float d = abs(perpD - displacement);
    float bolt = smoothstep(thickness, thickness * 0.15, d);

    // Fade at ends
    bolt *= smoothstep(0.0, 0.1, t_along) * smoothstep(1.0, 0.9, t_along);

    // Glow around bolt
    float glow = exp(-d * d / (0.0003)) * 0.5;
    glow *= smoothstep(0.0, 0.15, t_along) * smoothstep(1.0, 0.85, t_along);

    return bolt + glow;
}

// ─── TYPING: Lightning bolts striking characters (sometimes) ─────────
vec4 typingEffect(vec2 vu, vec2 cursorCenter, vec2 cursorSize, float progress, vec4 base) {
    float t = progress;
    float invT = 1.0 - t;

    vec2 toCursor = vu - cursorCenter;
    float dist = length(toCursor);

    // Only ~30% of keystrokes trigger lightning
    float chance = hash(vec2(iTimeCursorChange * 123.456, 7.89));
    bool doLightning = chance < 0.3;

    float bolts = 0.0;
    vec3 boltColor = vec3(0.0);
    float boltTotal = 0.0;

    // Lightning bolts — only on ~30% of keystrokes
    float arc = 0.0;
    if (doLightning) {
        for (int i = 0; i < 10; i++) {
            float fi = float(i);
            float seed = hash(vec2(fi, iTimeCursorChange));
            float seed2 = hash(vec2(fi * 7.3, iTimeCursorChange + 1.0));
            float seed3 = hash(vec2(fi * 13.1, iTimeCursorChange + 2.0));

            float boltBirth = seed * 0.15;
            float boltLife = 0.15 + seed2 * 0.2;
            float localT = clamp((t - boltBirth) / boltLife, 0.0, 1.0);
            if (localT <= 0.0 || localT >= 1.0) continue;

            float flash = localT < 0.2 ? localT / 0.2 : (1.0 - localT) / 0.8;
            flash = flash * flash;

            float strikeAngle = seed * 6.28318 + seed2 * 0.5;
            float strikeDist = 0.03 + seed3 * 0.06;
            vec2 strikeTarget = cursorCenter + vec2(cos(strikeAngle), sin(strikeAngle)) * strikeDist;

            float b = boltLine(vu, cursorCenter, strikeTarget, seed, iTime + fi) * flash;

            float impactDist = length(vu - strikeTarget);
            float impact = exp(-impactDist * impactDist / 0.00015) * flash * 0.8;

            vec2 midpoint = mix(cursorCenter, strikeTarget, 0.4 + seed * 0.3);
            float branchAngle = strikeAngle + (seed2 > 0.5 ? 0.8 : -0.8);
            float branchLen = strikeDist * 0.4;
            vec2 branchTarget = midpoint + vec2(cos(branchAngle), sin(branchAngle)) * branchLen;
            float branch = boltLine(vu, midpoint, branchTarget, seed + 50.0, iTime + fi) * flash * 0.6;

            float contribution = b + impact + branch;
            bolts += contribution;

            vec3 c = mix(BOLT_CORE, BOLT_GLOW, seed);
            c = mix(c, BOLT_FAINT, step(0.7, seed2));
            c = mix(c, BOLT_WHITE, smoothstep(0.3, 0.8, b));
            boltColor += c * contribution;
            boltTotal += contribution;
        }

        // Electric arc glow around cursor
        float arcNoise = noise(vec2(atan(toCursor.y, toCursor.x) * 5.0 + iTime * 15.0, dist * 50.0));
        arc = smoothstep(0.025, 0.008, dist) * arcNoise * invT * invT * 0.6;
    }

    // Core glow
    float coreGlow = exp(-dist * dist / (0.0003 * invT + 0.000001)) * invT * invT;

    vec3 finalColor = boltTotal > 0.001 ? boltColor / boltTotal : BOLT_CORE;
    finalColor = mix(finalColor, BOLT_WHITE, coreGlow * 0.5);

    float totalAlpha = clamp(bolts * 0.9 + arc + coreGlow * 0.6, 0.0, 1.0);
    return vec4(mix(base.rgb, finalColor, totalAlpha), base.a);
}

// ─── DELETING: Swarm of scattered explosions ─────────────────────────
vec4 deletingEffect(vec2 vu, vec2 cursorCenter, vec2 prevCenter, vec2 cursorSize, float progress, vec4 base, float cellsDeleted) {
    float t = progress;
    float invT = 1.0 - t;

    vec2 moveDir = cursorCenter - prevCenter;
    float moveDist = length(moveDir);
    vec2 moveNorm = moveDist > 0.001 ? moveDir / moveDist : vec2(-1.0, 0.0);
    vec2 movePerp = vec2(-moveNorm.y, moveNorm.x);

    // More explosions: 3-4 per deleted cell, scattered around
    int numExplosions = int(clamp(cellsDeleted * 3.5, 8.0, 30.0));

    vec3 totalColor = vec3(0.0);
    float totalAlpha = 0.0;

    for (int i = 0; i < 30; i++) {
        if (i >= numExplosions) break;
        float fi = float(i);
        float seed = hash(vec2(fi, iTimeCursorChange));
        float seed2 = hash(vec2(fi * 3.7, iTimeCursorChange + 1.0));
        float seed3 = hash(vec2(fi * 11.3, iTimeCursorChange + 2.0));

        // Scatter explosions across the deleted region, not just on the line
        float alongT = seed; // random position along prev→current
        vec2 basePos = mix(prevCenter, cursorCenter, alongT);

        // Scatter perpendicular and slightly vertical for chaos
        float scatterPerp = (seed2 - 0.5) * 0.04;
        float scatterVert = (seed3 - 0.5) * 0.03;
        vec2 explosionCenter = basePos + movePerp * scatterPerp + vec2(0.0, scatterVert);

        // Stagger timing — rapid popcorn sequence
        float delay = seed * 0.3 + seed2 * 0.1;
        float localT = clamp((t - delay) / (0.4 + seed3 * 0.2), 0.0, 1.0);
        if (localT <= 0.0) continue;
        float localInvT = 1.0 - localT;

        vec2 toE = vu - explosionCenter;
        float eDist = length(toE);

        // Expanding ring — varied sizes
        float ringR = easeOut(localT) * (0.008 + seed * 0.015);
        float ringW = 0.002 * localInvT;
        float ring = smoothstep(ringW, 0.0, abs(eDist - ringR)) * localInvT;

        // Core flash — bright hot pop
        float flashSize = 0.00008 + seed2 * 0.00012;
        float flash = exp(-eDist * eDist / (flashSize * localInvT + 0.000001)) * localInvT;

        // Sparks flying out — 6 per explosion
        float sparks = 0.0;
        for (int j = 0; j < 6; j++) {
            float fj = float(j);
            float pSeed = hash(vec2(fi * 5.0 + fj, iTimeCursorChange));
            float pAngle = fj * 6.28318 / 6.0 + pSeed * 1.2;
            float pSpeed = (0.008 + pSeed * 0.018);

            vec2 pPos = explosionCenter + vec2(cos(pAngle), sin(pAngle)) * pSpeed * localT;
            pPos.y -= localT * localT * 0.006; // gravity

            float pDist = length(vu - pPos);
            float pSize = (0.0012 + pSeed * 0.001) * (1.0 - localT);
            sparks += exp(-pDist * pDist / (pSize * pSize + 0.000001)) * localInvT;
        }

        // Heat color
        float heat = flash + sparks * 0.3;
        vec3 eColor = mix(BOOM_HOT, BOOM_EMBER, seed);
        eColor = mix(eColor, BOOM_CORE, smoothstep(0.3, 0.8, heat));
        eColor = mix(eColor, vec3(1.0, 0.95, 0.85), smoothstep(0.6, 1.0, flash));

        float eAlpha = clamp(ring * 0.6 + flash * 0.9 + sparks * 0.7, 0.0, 1.0);
        totalColor += eColor * eAlpha;
        totalAlpha += eAlpha;
    }

    // Residual ember glow across the deleted region
    float regionAlong = dot(vu - prevCenter, moveNorm) / max(moveDist, 0.001);
    float regionPerp = abs(dot(vu - prevCenter, movePerp));
    float regionMask = smoothstep(0.0, 0.05, regionAlong) * smoothstep(1.2, 0.8, regionAlong)
                     * smoothstep(0.03, 0.005, regionPerp) * invT * invT;
    float emberFlicker = noise(vu * 60.0 + iTimeCursorChange * 5.0);
    totalColor += BOOM_EMBER * regionMask * emberFlicker * 0.5;
    totalAlpha += regionMask * emberFlicker * 0.3;

    if (totalAlpha > 0.001) {
        totalColor /= totalAlpha;
        totalAlpha = clamp(totalAlpha, 0.0, 1.0);
    }

    return vec4(mix(base.rgb, totalColor, totalAlpha), base.a);
}

// ─── MOVEMENT: Warp streak + particles ───────────────────────────────
vec4 movementEffect(vec2 vu, vec2 cursorCenter, vec2 prevCenter, vec2 cursorSize, float progress, vec4 base) {
    float t = progress;
    float invT = 1.0 - t;

    vec2 moveDir = cursorCenter - prevCenter;
    float moveDist = length(moveDir);
    if (moveDist < 0.001) return base;
    vec2 moveNorm = moveDir / moveDist;
    vec2 movePerp = vec2(-moveNorm.y, moveNorm.x);

    vec2 toFrag = vu - prevCenter;
    float along = dot(toFrag, moveNorm);
    float perp = dot(toFrag, movePerp);

    float trailHead = moveDist * easeOut(t);
    float trailTail = moveDist * easeOut(t) * t;
    float inTrail = smoothstep(trailTail - 0.01, trailTail + 0.005, along)
                  * smoothstep(trailHead + 0.005, trailHead - 0.01, along);

    float taperT = clamp((along - trailTail) / max(trailHead - trailTail, 0.001), 0.0, 1.0);
    float width = mix(0.03, 0.004, taperT) * MOVE_INTENSITY;

    float wave = sin(along * 120.0 + iTime * 20.0) * 0.003 * invT;
    float streakMask = smoothstep(width, width * 0.2, abs(perp + wave)) * inTrail * invT;

    // Speed lines
    float speedLines = 0.0;
    for (int i = -3; i <= 3; i++) {
        if (i == 0) continue;
        float offset = float(i) * 0.012;
        float lp = abs(perp - offset + wave * 0.5);
        float lw = 0.001 + 0.001 * hash(vec2(float(i), iTimeCursorChange));
        float la = smoothstep(lw, 0.0, lp) * inTrail * invT * 0.4;
        float stagger = hash(vec2(float(i) * 3.1, iTimeCursorChange)) * moveDist * 0.3;
        la *= smoothstep(trailTail + stagger, trailTail + stagger + 0.01, along);
        speedLines += la;
    }

    // Particles flying off the streak
    float particles = 0.0;
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float seed = hash(vec2(fi, iTimeCursorChange));
        float seed2 = hash(vec2(fi * 5.3, iTimeCursorChange + 1.0));

        float birthT = seed * 0.4;
        float localT = clamp((t - birthT) / (1.0 - birthT), 0.0, 1.0);
        if (localT <= 0.0) continue;

        float spawnAlong = seed * moveDist;
        vec2 spawnPos = prevCenter + moveNorm * spawnAlong;
        float flySign = (seed2 > 0.5 ? 1.0 : -1.0);
        float flyDist = localT * 0.02 * (0.5 + seed2);
        vec2 pPos = spawnPos + movePerp * flySign * flyDist + moveNorm * localT * 0.005;

        float pDist = length(vu - pPos);
        float pSize = 0.002 * (1.0 - localT);
        particles += exp(-pDist * pDist / (pSize * pSize + 0.000001)) * (1.0 - localT);
    }

    // Head glow
    float headDist = length(vu - (prevCenter + moveNorm * trailHead));
    float headGlow = exp(-headDist * headDist / (0.0008 * invT + 0.00001)) * invT;

    // Ghost
    float ghostDist = length(vu - prevCenter);
    float ghost = exp(-ghostDist * ghostDist / 0.001) * invT * invT * 0.5;
    float ghostRect = smoothstep(0.002, 0.0, getSdfRect(vu, prevCenter, cursorSize * 0.5)) * invT * invT * 0.4;

    vec3 warpCol = mix(WARP_ACCENT, WARP_COLOR, taperT);
    float totalAlpha = clamp(streakMask * 0.8 + speedLines + headGlow * 0.9 + ghost + ghostRect + particles * 0.6, 0.0, 1.0);

    return vec4(mix(base.rgb, warpCol, totalAlpha), base.a);
}

// ─── Main ────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 curRaw = iCurrentCursor;
    vec4 prevRaw = iPreviousCursor;

    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float shakeProgress = clamp((iTime - iTimeCursorChange) / SHAKE_DURATION, 0.0, 1.0);

    float dist = distance(curRaw.xy, prevRaw.xy);
    int action = detectAction(curRaw, prevRaw);

    // ── Global screen shake ──
    vec2 shakeOff = vec2(0.0);
    if (shakeProgress < 1.0 && dist > 0.5) {
        float mult = action == 2 ? SHAKE_MOVE_MULT
                   : action == 1 ? SHAKE_DEL_MULT
                   : SHAKE_TYPE_MULT;
        shakeOff = calcShake(shakeProgress, mult);
    }

    vec2 shakenUV = clamp(fragCoord / iResolution.xy + shakeOff, 0.0, 1.0);
    fragColor = texture(iChannel0, shakenUV);

    if (progress >= 1.0 || dist < 0.5) return;

    vec2 vu = normPos(fragCoord + shakeOff * iResolution.xy);
    vec2 cursorCenter = normPos(curRaw.xy + curRaw.zw * vec2(0.5, -0.5));
    vec2 prevCenter   = normPos(prevRaw.xy + prevRaw.zw * vec2(0.5, -0.5));
    vec2 cursorSize   = normSize(curRaw.zw);

    if (action == 0) {
        fragColor = typingEffect(vu, cursorCenter, cursorSize, progress, fragColor);
    } else if (action == 1) {
        float cellsDeleted = abs((curRaw.x - prevRaw.x) / max(curRaw.z, 1.0));
        fragColor = deletingEffect(vu, cursorCenter, prevCenter, cursorSize, progress, fragColor, cellsDeleted);
    } else {
        fragColor = movementEffect(vu, cursorCenter, prevCenter, cursorSize, progress, fragColor);
    }
}
