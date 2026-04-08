import SwiftUI

struct ContentView: View {
    private enum CardPhase {
        case idle
        case stretched
        case travelTaffy
        case atIsland
    }

    @State private var phase: CardPhase = .idle
    @State private var islandSwallow = false
    @State private var blurRadius: CGFloat = 0

    /// Full travel duration used for 60% taffy / 40% compress split and blur / island timing.
    private let travelTotal: TimeInterval = 0.52

    private let stretchSpring = Animation.spring(response: 0.25, dampingFraction: 0.86)
    private let taffyTravelSpring = Animation.spring(response: 0.5, dampingFraction: 0.7)
    private let arrivalCompressSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)
    private let islandSettleSpring = Animation.spring(response: 0.45, dampingFraction: 0.72)

    private var scaleX: CGFloat {
        switch phase {
        case .idle: 1
        case .stretched: 0.9
        case .travelTaffy: 0.5
        case .atIsland: 0.48
        }
    }

    private var scaleY: CGFloat {
        switch phase {
        case .idle: 1
        case .stretched: 1.3
        case .travelTaffy: 1.8
        case .atIsland: 0.14
        }
    }

    private var scaleAnchor: UnitPoint {
        switch phase {
        case .idle: .center
        case .stretched, .travelTaffy: .top
        case .atIsland: .bottom
        }
    }

    private var offsetY: CGFloat {
        switch phase {
        case .idle, .stretched: 0
        case .travelTaffy, .atIsland: -420
        }
    }

    private var corner: CGFloat {
        phase == .atIsland ? 20 : 32
    }

    private let islandBaseW: CGFloat = 126
    private let islandBaseH: CGFloat = 37

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geo.size.height * 0.44)
                    ZStack {
                        LinearGradient(
                            colors: [Color.indigo, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "photo.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(width: 260, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .scaleEffect(x: scaleX, y: scaleY, anchor: scaleAnchor)
                    .blur(radius: blurRadius)
                    .offset(y: offsetY)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)
                .frame(
                    width: islandSwallow ? islandBaseW + 8 : islandBaseW,
                    height: islandSwallow ? islandBaseH + 4 : islandBaseH
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: 11)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch phase {
            case .idle:
                expandSequence()
            case .atIsland:
                collapseSequence()
            case .stretched, .travelTaffy:
                break
            }
        }
    }

    private func expandSequence() {
        withAnimation(stretchSpring) {
            phase = .stretched
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(taffyTravelSpring) {
                phase = .travelTaffy
                islandSwallow = true
            }
            let t0 = travelTotal / 3
            let t1 = 2 * travelTotal / 3
            DispatchQueue.main.asyncAfter(deadline: .now() + t0) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    blurRadius = 6
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + t1) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    blurRadius = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 * travelTotal) {
                withAnimation(arrivalCompressSpring) {
                    phase = .atIsland
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + travelTotal) {
                withAnimation(islandSettleSpring) {
                    islandSwallow = false
                }
            }
        }
    }

    private func collapseSequence() {
        blurRadius = 0
        withAnimation(taffyTravelSpring) {
            phase = .stretched
            islandSwallow = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(stretchSpring) {
                phase = .idle
            }
        }
    }
}

#Preview {
    ContentView()
}
