//
//  UNDERGROUND__IOS_Innovation_studioApp.swift
//  UNDERGROUND- IOS Innovation studio
//
//  Created by Gravhit on 28/05/26.
//

import SwiftUI

@main
struct UNDERGROUND__IOS_Innovation_studioApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashScreenView()
                        .transition(
                            .opacity.combined(with: .scale(scale: 1.04))
                        )
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
