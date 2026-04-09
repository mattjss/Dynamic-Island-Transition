#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Genie suction toward Dynamic Island (126/260 width); extra floats are debug uniforms.
[[ stitchable ]] float2 taffyWarp(float2 position, float4 bounds, float progress, float time, float pinchIntensity, float wobbleAmplitude, float wobbleFrequency, float verticalSuction) {
    float minX = bounds.x;
    float minY = bounds.y;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);

    float CX = minX + w * 0.5f;

    float uOut = (position.x - CX) / w + 0.5f;
    float vOut = (position.y - minY) / h;

    float p = clamp(progress, 0.0f, 1.0f);
    float pinchK = max(pinchIntensity, 0.05f);
    float wobbleK = max(wobbleAmplitude, 0.0f);
    float wobbleF = max(wobbleFrequency, 0.05f);
    float vertK = max(verticalSuction, 0.01f);

    // Row weight: 0 = top (mouth / portal), 1 = bottom (taffy tail).
    float tail = pow(saturate(vOut), 0.78f);

    // Top leads: full suction curve by ~mid progress. Bottom trails: shifted smoothstep (elastic lag).
    float phaseTop = smoothstep(0.0f, 0.48f, p);
    float phaseBot = smoothstep(0.14f, 0.98f, p);
    float pRow = mix(phaseTop, phaseBot, tail);

    // Trailing elastic wobble (stronger on bottom, only mid-flight).
    float wobbleAmp = 0.014f * p * (1.0f - p) * tail * wobbleK;
    float uWobble = wobbleAmp * sin(time * (5.5f * wobbleF) + vOut * 9.0f);
    float vWobble = wobbleAmp * cos(time * (4.8f * wobbleF) + vOut * 11.0f);

    // Horizontal genie pinch: collapse width toward island ratio 126/260 as progress increases.
    constexpr float islandRatio = 126.0f / 260.0f;
    float pinchTop = mix(1.0f, islandRatio, saturate(pRow * pinchK * (1.0f + 0.5f * (1.0f - vOut))));
    float pinchBot = mix(1.0f, islandRatio, saturate(pRow * pinchK * 0.62f));
    float pinch = mix(pinchTop, pinchBot, smoothstep(0.0f, 1.0f, vOut));

    float uNorm = (uOut - 0.5f) / max(pinch, 0.001f) + 0.5f + uWobble;
    uNorm = saturate(uNorm);

    // Vertical suction: top rows reach the portal first; bottom lags. vertK scales compression strength.
    float suck = pow(saturate(pRow), 0.88f);
    float vCompress = mix(1.0f, 0.04f, saturate(suck * vertK));
    float taper = (1.0f - suck) * tail * 0.12f * sin(p * 3.14159265f);
    float vNorm = saturate(vOut * vCompress + taper + vWobble);

    return float2(minX + uNorm * w, minY + vNorm * h);
}
