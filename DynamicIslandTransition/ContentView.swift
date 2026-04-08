import SwiftUI

/// 258×258 card with a landscape photo: centered horizontally, ~60% down the screen.
/// Tap animates to the Dynamic Island over ~1.4s with a spring. During travel, a top-anchored
/// squeeze (GeometryEffect) pinches the card toward the pill — same role as a Metal squeeze,
/// without Metal/shader build fragility across Xcode SDKs.
struct ContentView: View {
    @State private var travelProgress: CGFloat = 0

    var body: some View {
        IslandTravelCard(progress: travelProgress)
            .animation(.spring(duration: 1.4), value: travelProgress)
            .onTapGesture {
                travelProgress = travelProgress < 0.5 ? 1 : 0
            }
    }
}

// MARK: - Animatable card (progress interpolates during the spring)

struct IslandTravelCard: View, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private let cardSize: CGFloat = 258
    private let islandWidth: CGFloat = 126
    private let islandHeight: CGFloat = 37
    private let islandTopOffset: CGFloat = 11
    /// Tuned to match the prior Metal shader’s “~4.8” strength visually.
    private let squeezeStrength: CGFloat = 4.8

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let centerX = geometry.size.width / 2
            let startCenterY = geometry.size.height * 0.6
            let islandCenterY = safeTop + islandTopOffset + islandHeight / 2

            let t = max(0, min(1, progress))
            let w = cardSize + (islandWidth - cardSize) * t
            let h = cardSize + (islandHeight - cardSize) * t
            let cy = startCenterY + (islandCenterY - startCenterY) * t
            let corner = (cardSize * 0.22) * (1 - t) + (min(islandWidth, islandHeight) / 2) * t

            let travelBlend = CGFloat(sin(Double(t) * .pi))

            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                landscapeCard(width: w, height: h)
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .modifier(TopIslandSqueezeEffect(amount: travelBlend * squeezeStrength))
                    .position(x: centerX, y: cy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }

    private func landscapeCard(width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: landscapePhotoURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            case .failure:
                landscapePlaceholder
                    .frame(width: width, height: height)
            case .empty:
                ZStack {
                    Color.secondary.opacity(0.2)
                    ProgressView()
                }
                .frame(width: width, height: height)
            @unknown default:
                landscapePlaceholder
                    .frame(width: width, height: height)
            }
        }
    }

    private var landscapePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.35, blue: 0.55), Color(red: 0.45, green: 0.65, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var landscapePhotoURL: URL? {
        URL(string: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=80")
    }
}

// MARK: - Top squeeze (replaces Metal distortion; anchor = Dynamic Island side)

private struct TopIslandSqueezeEffect: GeometryEffect {
    /// `sin(π·t) * squeezeStrength` — peaks mid-flight, strongest near top via gradient mask.
    var amount: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard amount > 0.001 else { return ProjectionTransform(.identity) }

        let normalized = min(amount / 4.8, 1.5)
        let scaleY = 1.0 - normalized * 0.11
        let scaleX = 1.0 - normalized * 0.028

        var t = CGAffineTransform.identity
        t = t.translatedBy(x: size.width / 2, y: 0)
        t = t.scaledBy(x: scaleX, y: scaleY)
        t = t.translatedBy(x: -size.width / 2, y: 0)
        return ProjectionTransform(t)
    }
}

extension TopIslandSqueezeEffect: Animatable {
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
}

#Preview {
    ContentView()
}
