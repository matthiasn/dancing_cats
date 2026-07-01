#include <flutter/runtime_effect.glsl>

precision highp float;

// ASC CDL primary colour grade applied to the composited backdrop image:
//   graded = (slope * c + offset) ^ power       // Slope -> Offset -> Power
//   out    = mix(luma(graded), graded, saturation)   // Rec.709 saturation
// Slope is a multiply (moves highlights), Offset an add (moves shadows), Power a
// gamma (moves midtones), so the three map onto a 3-way colour-wheel UI. Uniform
// order MUST match BackdropGradePainter's setFloat calls.

uniform vec2 uResolution;
uniform vec3 uSlope;       // per-channel multiply (gain / highlights)
uniform vec3 uOffset;      // per-channel add (lift / shadows)
uniform vec3 uPower;       // per-channel gamma exponent (midtones)
uniform float uSaturation; // Rec.709 saturation (1 = unchanged)
uniform sampler2D uTexture; // the composited backdrop to grade

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 src = texture(uTexture, uv);
  // The backdrop is opaque (the base plate fills the frame), so grade RGB
  // straight; max() keeps the base of pow() non-negative.
  vec3 c = max(uSlope * src.rgb + uOffset, vec3(0.0));
  c = pow(c, uPower);
  float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = mix(vec3(luma), c, uSaturation);
  fragColor = vec4(c, src.a);
}
