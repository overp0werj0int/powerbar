#version 440
// The camera's beam on the Layout page (PREFS-24): one shade for the notch's
// cap, the beam below it and the Center tiles it falls on, so nothing steps
// where a tile meets a gap. Black, premultiplied.
//
// u runs across the beam (-1..1 at the Center tile's edges), v down the bar
// layer's plane from its top edge (plane units, as PreferencesModel's
// tiltedDepth gives them). Each item drawing with this shader says which v
// its top and bottom are at, so the same function continues across items.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float peak;    // how dark the beam is where it leaves the cap
    float vTop;    // this item's top and bottom, in v
    float vBottom;
    float capEnd;  // v where the cap's solid black starts giving way to the beam
    float capFade; // v where it has fully become the beam
    float span;    // v where the beam has faded out
    float edge;    // the soft edge across, in u (about a pixel)
    float taper;   // how wide the beam still is where it fades out, 0..1
};

void main() {
    float u = qt_TexCoord0.x * 2.0 - 1.0;
    float au = abs(u);
    float v = mix(vTop, vBottom, qt_TexCoord0.y);
    // Down the page: full at the top, gone at the end, no slope at either.
    float t = clamp(v / max(span, 1.0), 0.0, 1.0);
    float down = 1.0 - t * t * (3.0 - 2.0 * t);
    // Across: full and nearly crisp at the cap's width where the beam
    // leaves it, then thinning from the outside in and softening as it
    // goes down the page, like a flame.
    float wide = mix(1.0, taper, t);
    float soft = mix(0.2, 0.7, t);
    float across = 1.0 - smoothstep(max(wide - soft, 0.0), wide, au);
    // The cap is solid and full width; it becomes the beam gradually.
    float cap = 1.0 - smoothstep(capEnd, capFade, v);
    float shape = mix(across, 1.0, cap);
    float level = mix(peak, 1.0, cap);
    float a = shape * level * down;
    // A soft edge across, so the tilted sides do not step.
    a *= 1.0 - smoothstep(1.0 - edge, 1.0, au);
    // A grain of noise hides banding on dark themes.
    float n = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
    a = clamp(a + (n - 0.5) / 255.0, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(0.0, 0.0, 0.0, a);
}
