import SwiftUI

/// Hero image that transitions between screen center and Dynamic Island–sized capsule at the top.
struct ContentView: View {
    @Namespace private var imageNamespace
    @State private var isAtIsland = false

    private let expandedSize: CGFloat = 220
    private let islandWidth: CGFloat = 126
    private let islandHeight: CGFloat = 37
    /// Distance from the top safe area to the top edge of the island frame.
    private let islandTopOffset: CGFloat = 11

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            let centerX = geometry.size.width / 2
            // Vertical center of the safe-area content (true “on screen” center).
            let centerY = safeTop + (geometry.size.height - safeTop - safeBottom) / 2
            // Center of the 126×37 island: top edge at safeTop + 11, then half height down.
            let islandCenterY = safeTop + islandTopOffset + islandHeight / 2

            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if isAtIsland {
                    heroImage
                        .frame(width: islandWidth, height: islandHeight)
                        .clipShape(Capsule(style: .continuous))
                        .matchedGeometryEffect(id: "hero", in: imageNamespace)
                        .position(x: centerX, y: islandCenterY)
                } else {
                    heroImage
                        .frame(width: expandedSize, height: expandedSize)
                        .clipShape(RoundedRectangle(cornerRadius: expandedSize * 0.22, style: .continuous))
                        .matchedGeometryEffect(id: "hero", in: imageNamespace)
                        .position(x: centerX, y: centerY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.52, dampingFraction: 0.82), value: isAtIsland)
            .onTapGesture {
                isAtIsland.toggle()
            }
        }
    }

    private var heroImage: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .symbolRenderingMode(.hierarchical)
        }
    }
}

#Preview {
    ContentView()
}
