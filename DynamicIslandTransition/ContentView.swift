import SwiftUI

struct ContentView: View {
    @State private var progress: CGFloat = 0
    @State private var suckedIn = false
    @State private var islandBump = false

    private let travelSpring = Animation.spring(response: 0.45, dampingFraction: 0.72)
    private let cardW: CGFloat = 260
    private let cardH: CGFloat = 260
    /// Lifts card toward Dynamic Island as progress runs 0 → 1.
    private let liftPerProgress: CGFloat = 410
    private let islandBaseW: CGFloat = 126
    private let islandBaseH: CGFloat = 37

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geo.size.height * 0.44)
                    HStack {
                        Spacer(minLength: 0)
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                            let time = context.date.timeIntervalSinceReferenceDate
                            Image("CardPhoto")
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardW, height: cardH)
                                .clipped()
                                .distortionEffect(
                                    Shader(
                                        function: ShaderFunction(library: .default, name: "taffyWarp"),
                                        arguments: [
                                            .boundingRect,
                                            .float(Double(progress)),
                                            .float(time),
                                        ]
                                    ),
                                    maxSampleOffset: CGSize(width: 200, height: 480),
                                    isEnabled: true
                                )
                                .offset(y: -progress * liftPerProgress)
                                .opacity(progress >= 0.998 ? 0 : 1)
                        }
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Capsule()
                .fill(Color.black)
                .frame(
                    width: islandBump ? islandBaseW + 6 : islandBaseW,
                    height: islandBump ? islandBaseH + 3 : islandBaseH
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: 11)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            suckedIn.toggle()
            withAnimation(travelSpring) {
                progress = suckedIn ? 1 : 0
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            if suckedIn, newValue >= 0.85, oldValue < 0.85 {
                playIslandBump()
            }
        }
    }

    private func playIslandBump() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
            islandBump = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                islandBump = false
            }
        }
    }
}

#Preview {
    ContentView()
}
