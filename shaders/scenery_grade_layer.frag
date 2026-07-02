#include <flutter/runtime_effect.glsl>

precision highp float;

// ASC CDL primary grade for a SINGLE translucent layer (ADR 0002 §3).
//
// The whole-composite variant (scenery_grade.frag) grades an opaque frame, so
// it can grade raw RGB. A per-layer offscreen is PREMULTIPLIED alpha: grading
// premultiplied RGB with a non-zero Offset would lift fully-transparent
// pixels, haloing every feathered edge. So this variant un-premultiplies
// (where alpha > 0), grades straight RGB through the same
// Slope -> Offset -> Power -> Contrast -> Saturation pipeline, clamps to the
// displayable range, and re-premultiplies so rgb <= a stays valid. Alpha
// itself is never changed — a grade recolours a layer, it never reshapes it.
// Uniform order MUST match the whole-composite shader (the painter shares one
// wiring routine).

uniform vec2 uResolution;
uniform vec3 uSlope;       // per-channel multiply (gain / highlights)
uniform vec3 uOffset;      // per-channel add (lift / shadows)
uniform vec3 uPower;       // per-channel gamma exponent (midtones)
uniform float uSaturation; // Rec.709 saturation (1 = unchanged)
uniform float uContrast;   // contrast about uPivot (1 = unchanged)
uniform float uPivot;      // tonal pivot the contrast rotates about
uniform sampler2D uTexture; // the layer's premultiplied offscreen

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 src = texture(uTexture, uv);
  float a = src.a;
  if (a <= 0.0) {
    // Fully transparent: nothing to grade, and un-premultiplying would
    // divide by zero. Pass through so the layer's silhouette is untouched.
    fragColor = src;
    return;
  }
  vec3 c = src.rgb / a; // un-premultiply -> straight RGB
  c = max(uSlope * c + uOffset, vec3(0.0));
  c = pow(c, uPower);
  c = max((c - uPivot) * uContrast + uPivot, vec3(0.0));
  float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = mix(vec3(luma), c, uSaturation);
  c = min(c, vec3(1.0)); // keep rgb <= a valid after re-premultiplying
  fragColor = vec4(c * a, a);
}
