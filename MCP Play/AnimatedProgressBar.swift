//
//  AnimatedProgressBar.swift
//  MCP Play
//
//  Custom progress bar implementation that supports smooth animations.
//
//  Why not use ProgressView?
//  ProgressView's `value` parameter is not animatable in SwiftUI. When you animate
//  a value fed to ProgressView(value:total:), SwiftUI only sees discrete frames
//  (0 → totalDuration) rather than interpolating intermediate values. This is because
//  `value` isn't part of the view's AnimatableData. Additionally, the UIKit/AppKit
//  bridge passes animated:false for all diff-based updates, so even the underlying
//  platform controls don't animate.
//
//  This Rectangle-based approach works because CGFloat frame width IS part of
//  SwiftUI's AnimatableData, allowing smooth interpolation over the animation duration.
//

import SwiftUI

struct AnimatedProgressBar: View {
    let progress: Double
    let total: Double
    let height: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        progress: Double,
        total: Double,
        height: CGFloat = 6,
        backgroundColor: Color = Color.gray.opacity(0.3),
        foregroundColor: Color = Color.blue
    ) {
        self.progress = progress
        self.total = total
        self.height = height
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(height: height)
                
                Rectangle()
                    .fill(foregroundColor)
                    .frame(
                        width: geometry.size.width * (progress / max(total, 1.0)),
                        height: height
                    )
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedProgressBar(progress: 0.3, total: 1.0)
        AnimatedProgressBar(progress: 45, total: 180, foregroundColor: .green)
        AnimatedProgressBar(progress: 7.5, total: 10, height: 8, foregroundColor: .orange)
    }
    .padding()
}