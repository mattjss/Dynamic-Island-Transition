#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Distortion: returns **source** sample coordinates for each **destination** pixel.
/// Strongest vertical squeeze near the top of the layer (Dynamic Island side) so the card reads as being pulled into the pill.
[[ stitchable ]] float2 IslandSqueeze(
    float2 position,
    float2 size,
    float travelBlend,
    float squeezeStrength
) {
    if (size.x < 1.0f || size.y < 1.0f) {
        return position;
    }

    float w = size.x;
    float h = size.y;
    float ny = position.y / h;

    // 1 at top (nearest island), 0 at bottom — “zone nearest the dynamic island”
    float islandZone = 1.0f - ny;
    islandZone = islandZone * islandZone;

    float midY = h * 0.5f;
    float pullTowardCenter = (midY - position.y) / h;

    float amount = squeezeStrength * travelBlend * islandZone;
    // Vertical squeeze: remap Y toward midline (pinches height, reads as suction into the pill)
    float ySrc = position.y + pullTowardCenter * amount * 0.11f;

    // Slight horizontal pinch at the top to suggest capsule cross-section
    float cx = w * 0.5f;
    float pinch = amount * 0.045f * islandZone;
    float xSrc = cx + (position.x - cx) * (1.0f - pinch);

    return float2(xSrc, ySrc);
}
