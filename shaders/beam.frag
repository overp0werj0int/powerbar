#version 440
// The camera's cap on the Preferences pages (PREFS-24): solid black from the
// page's top down to a torn paper edge a little above the plates, the
// paper's lighter core showing along the tear, and a soft shade falling a
// short way under it, over the gaps and the tiles alike, so nothing steps
// where a tile meets a gap. Premultiplied.
//
// x runs across the camera's column (plane px from its middle), v down the
// bar layer's plane from its top edge (plane units, as PreferencesModel's
// tiltedDepth gives them), turned back into seen page px for the tear. Each
// item drawing with this shader says which v its top and bottom are at, so
// the same function continues across items. The numbers are CameraLook's.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 fringeColor;     // the paper's core (straight alpha 1)
    float vTop;           // this item's top and bottom, in v
    float vBottom;
    float edge;           // the soft edge at the column's sides, in u (about a pixel)
    float colWidth;       // the camera's column, plane px
    float outer;          // how far this item reaches past each side of the column, px
    float spill;          // 1: only the shade past the column's sides (shadeSpread)
    float tiltCos;        // v to seen px: v * tiltCos / (1 - v * tiltK)
    float tiltK;
    float gapAbove;       // the tear's line above the plates, px
    float tearDepth;      // how far the edge wanders, px
    float grain;          // bumps per px
    float octaves;
    float seed;
    float fringeSeed;
    float fringeWidth;    // px past the fringe's own torn line
    float fringeStrength; // 0..1
    float shadeBlur;      // px either side of the shade's middle
    float shadeDrop;      // px from the edge to the shade's middle
    float shadeStrength;  // 0..1
    float shadeSpread;    // px past each side of the column
};

float hash(float i, float s) {
    return fract(sin(i * 127.1 + s * 311.7) * 43758.5453) * 2.0 - 1.0;
}
// Value noise along x, -1..1, eased between whole steps.
float noise(float x, float s) {
    float i = floor(x);
    float f = x - i;
    float e = f * f * (3.0 - 2.0 * f);
    return mix(hash(i, s), hash(i + 1.0, s), e);
}
// Fractional Brownian motion: octaves of finer noise at half the amplitude,
// normalised back to -1..1.
float fbm(float x, float s) {
    float sum = 0.0;
    float amp = 1.0;
    float norm = 0.0;
    for (int k = 0; k < 5; k++) {
        if (float(k) >= octaves)
            break;
        sum += amp * noise(x, s + float(k) * 17.0);
        norm += amp;
        amp *= 0.5;
        x *= 2.0;
    }
    return sum / max(norm, 1.0e-4);
}

void main() {
    float w = colWidth + 2.0 * outer;
    float x = (qt_TexCoord0.x - 0.5) * w;
    // -1..1 at the column's sides; an item no wider than the column keeps
    // the plain form, so the cap's sides are drawn bit for bit as before.
    float u = qt_TexCoord0.x * 2.0 - 1.0;
    if (outer > 0.0)
        u *= w / max(colWidth, 1.0);
    float au = abs(u);
    float v = mix(vTop, vBottom, qt_TexCoord0.y);
    // Seen px under the plates' top line (negative above it).
    float y = v * tiltCos / max(1.0 - v * tiltK, 1.0e-3);
    // The torn edge, and how far under it this pixel is.
    float d = y - (-gapAbove + tearDepth * fbm(x * grain, seed));
    // Antialiased over about a device pixel, across the edge's own slope.
    float cap = clamp(0.5 - d / max(fwidth(d), 1.0e-3), 0.0, 1.0);
    // The shade: the torn cap blurred and dropped. Down the page it fades
    // over shadeBlur either side of shadeDrop under the edge; across, the
    // edge it follows is itself blurred (five taps over the same reach,
    // binomial weights), so the shade does not streak under every tooth.
    float b = max(shadeBlur, 0.5);
    float soft = 0.0;
    for (int k = -2; k <= 2; k++) {
        float wk = k == 0 ? 6.0 : (k == 1 || k == -1) ? 4.0 : 1.0;
        soft += wk * fbm((x + float(k) * 0.5 * shadeBlur) * grain, seed);
    }
    float ds = y - (-gapAbove + tearDepth * soft / 16.0);
    float shade = shadeStrength * (1.0 - smoothstep(shadeDrop - b, shadeDrop + b, ds));
    float a;
    // The straight colour: black, but for the fringe.
    vec3 col = vec3(0.0);
    if (spill > 0.5) {
        // Past the sides only: a raised cosine over shadeSpread px.
        float t = clamp((abs(x) - 0.5 * colWidth) / max(shadeSpread, 1.0), 0.0, 1.0);
        float across = au <= 1.0 ? smoothstep(1.0 - edge, 1.0, au) : 0.5 + 0.5 * cos(3.14159265 * t);
        a = shade * across;
    } else {
        // Back to front: the shade, the fringe, the black cap.
        a = shade;
        vec3 rgb = vec3(0.0);
        if (fringeWidth > 0.0) {
            float fd = y - (-gapAbove + tearDepth * fbm(x * grain, fringeSeed) + fringeWidth);
            float f = fringeStrength * clamp(0.5 - fd / max(fwidth(fd), 1.0e-3), 0.0, 1.0);
            rgb = fringeColor.rgb * f;
            a = f + a * (1.0 - f);
        }
        rgb *= 1.0 - cap;
        a = cap + a * (1.0 - cap);
        col = a > 0.0 ? rgb / a : vec3(0.0);
        // The column's own soft sides, exactly as the cap always had them.
        a *= 1.0 - smoothstep(1.0 - edge, 1.0, au);
    }
    // A grain of noise hides banding on dark themes.
    float n = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
    a = clamp(a + (n - 0.5) / 255.0, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(col * a, a);
}
