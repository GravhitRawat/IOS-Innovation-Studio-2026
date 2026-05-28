import SwiftUI

struct SplashScreenView: View {
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 18
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 12

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            WavyLinesView()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Underground")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                Text("this is where every artist starts")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.3)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleOffset)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    titleOpacity = 1
                    titleOffset = 0
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.25)) {
                    subtitleOpacity = 1
                    subtitleOffset = 0
                }
            }
        }
    }
}
