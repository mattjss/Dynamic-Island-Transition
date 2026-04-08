#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Distortion: returns the layer coordinate to sample for each destination pixel.
/// progress 0 = identity. Top of card (small y) compresses toward image top first; bottom lags (taffy).
/// Horizontal pinch toward island width ratio (126/260). At progress 1, vertical span collapses to a thin strip at the top.
[[ stitchable ]] float2 taffyWarp(float2 position, float4 bounds, float progress, float time) {
    float minX = bounds.x;
    float minY = bounds.y;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);

    float uOut = (position.x - minX) / w;
    float vOut = (position.y - minY) / h;

    float p = clamp(progress, 0.0f, 1.0f);

    // Pinch X toward ~126pt relative to 260pt card.
    constexpr float islandWidthRatio = 126.0f / 260.0f;
    float pinch = mix(1.0f, islandWidthRatio, p);
    float uSrc = (uOut - 0.5f) / max(pinch, 0.001f) + 0.5f;

    // Vertical lag: bottom (vOut → 1) keeps more of the original span; top follows first.
    // At p≈0.7 and vOut=1, vSrc ≈ 0.5; at vOut=0, vSrc=0.
    float compress = p * vOut;
    float vSrc = vOut * (1.0f - 0.92f * compress);

    // Final crush: collapse remaining vertical extent into a thin band at the image top.
    float crush = smoothstep(0.65f, 1.0f, p);
    vSrc = mix(vSrc, 0.04f * (1.0f - p * 0.15f), crush);

    float2 src = float2(minX + uSrc * w, minY + vSrc * h);
    return src;
}
