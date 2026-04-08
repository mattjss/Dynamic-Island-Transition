import SwiftUI

/// Snappy spring + vacuum-style motion: card rushes toward the island, squashes, and snaps into the pill.
struct ContentView: View {
    @State private var travelProgress: CGFloat = 0

    /// ~0.4s feel (response correlates with settle time for a spring).
    private var travelSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.6)
    }

    var body: some View {
        IslandTravelCard(progress: travelProgress)
            .onTapGesture {
                withAnimation(travelSpring) {
                    travelProgress = travelProgress < 0.5 ? 1 : 0
                }
            }
    }
}

// MARK: - Card

struct IslandTravelCard: View {
    var progress: CGFloat

    private let cardSize: CGFloat = 258
    private let islandWidth: CGFloat = 126
    private let islandHeight: CGFloat = 37
    private let islandTopOffset: CGFloat = 11
    private let cornerExpanded: CGFloat = 22
    private var cornerPill: CGFloat { islandHeight / 2 }

    /// Y scale → near zero at end (sucked through a narrow slot); X narrows less aggressively.
    private let minVerticalScale: CGFloat = 0.08
    /// X scale at full progress (message was incomplete — adjust if you want a different end width).
    private let minHorizontalScale: CGFloat = 0.88

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let centerX = geometry.size.width / 2
            let startCenterY = geometry.size.height * 0.6
            let islandCenterY = safeTop + islandTopOffset + islandHeight / 2

            let t = max(0, min(1, progress))
            // Ease-in curve: most spatial change happens late so it feels vacuumed in, then snaps with the spring.
            let spatialT = pow(t, 1.9)

            let w = cardSize + (islandWidth - cardSize) * spatialT
            let h = cardSize + (islandHeight - cardSize) * spatialT
            let cy = startCenterY + (islandCenterY - startCenterY) * spatialT
            let corner = cornerExpanded * (1 - spatialT) + cornerPill * spatialT

            // Vacuum squeeze: Y collapses strongly toward the opening; X tapers more gently.
            let scaleY = 1 + (minVerticalScale - 1) * t
            let scaleX = 1 + (minHorizontalScale - 1) * t

            let td = Double(t)
            // Pulled-through-a-vacuum: wobble + skew strongest mid-travel, easing at ends.
            let wobbleDegrees = 7 * sin(td * .pi) * (1 - t * 0.35)
            let skew = 0.07 * sin(td * .pi * 1.5) * (1 - t)

            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                cardFill
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .scaleEffect(x: scaleX, y: scaleY, anchor: .top)
                    .rotationEffect(.degrees(wobbleDegrees), anchor: .top)
                    .transformEffect(
                        CGAffineTransform(a: 1, b: 0, c: CGFloat(skew), d: 1, tx: 0, ty: 0)
                    )
                    .position(x: centerX, y: cy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }

    /// Local-only content (swap for `AsyncImage` / asset when ready).
    private var cardFill: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.35, blue: 0.55), Color(red: 0.45, green: 0.65, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .symbolRenderingMode(.hierarchical)
        }
    }
}

#Preview {
    ContentView()
}
