//
//  MascotFaceView.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-08-11.
//

import SwiftUI

struct MascotFaceView: View {
    var color: Color = .blue
    @State private var isBobbing = false
    @State private var isBlinking = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 100, height: 100)
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                        .scaleEffect(y: isBlinking ? 0.1 : 1.0, anchor: .center)
                        .animation(.easeInOut(duration: 0.12), value: isBlinking)
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                        .scaleEffect(y: isBlinking ? 0.1 : 1.0, anchor: .center)
                        .animation(.easeInOut(duration: 0.12), value: isBlinking)
                }
                Capsule()
                    .fill(color)
                    .frame(width: 30, height: 6)
                    .offset(y: 6)
            }
        }
        // Gentle idle bob
        .offset(y: isBobbing ? -4 : 4)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isBobbing)
        .onAppear {
            // start bobbing
            isBobbing = true
        }
        // Periodic blink
        .task {
            while true {
                try? await Task.sleep(nanoseconds: 2_400_000_000) // wait ~2.4s
                isBlinking = true
                try? await Task.sleep(nanoseconds: 140_000_000)    // blink length ~0.14s
                isBlinking = false
            }
        }
    }
}
