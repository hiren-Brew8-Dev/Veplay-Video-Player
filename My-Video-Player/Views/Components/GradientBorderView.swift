//
//  GradientBorderView.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 29/11/25.
//

import SwiftUI

enum GradientBorderShape {
    case capsule
    case roundedRectangle(CGFloat)
}

enum GradientBorderDirection {
    case topToBottom
    case bottomToTop
    case leftToRight
    case rightToLeft
    case topLeftToBottomRight
    case bottomRightToTopLeft
    case angle(Double)
    
    func start() -> UnitPoint {
        switch self {
        case .topToBottom: return .top
        case .bottomToTop: return .bottom
        case .leftToRight: return .leading
        case .rightToLeft: return .trailing
        case .topLeftToBottomRight: return .topLeading
        case .bottomRightToTopLeft: return .bottomTrailing
        case .angle(let degrees):
            let rad = degrees * .pi / 180
            return UnitPoint(x: 0.5 - cos(rad)/2, y: 0.5 - sin(rad)/2)
        }
    }

    func end() -> UnitPoint {
        switch self {
        case .topToBottom: return .bottom
        case .bottomToTop: return .top
        case .leftToRight: return .trailing
        case .rightToLeft: return .leading
        case .topLeftToBottomRight: return .bottomTrailing
        case .bottomRightToTopLeft: return .topLeading
        case .angle(let degrees):
            let rad = degrees * .pi / 180
            return UnitPoint(x: 0.5 + cos(rad)/2, y: 0.5 + sin(rad)/2)
        }
    }
}

struct GradientBorderView: View {

    let borderColors: [Color]
    let backgroundColors: [Color]
    let borderWidth: CGFloat
    let direction: GradientBorderDirection
    let opacity: Double
    let shape: GradientBorderShape

    init(
        borderColors: [Color],
        backgroundColors: [Color],
        borderWidth: CGFloat = 3,
        direction: GradientBorderDirection = .topToBottom,
        opacity: Double = 1.0,
        shape: GradientBorderShape = .roundedRectangle(16)
    ) {
        self.borderColors = borderColors
        self.backgroundColors = backgroundColors
        self.borderWidth = borderWidth
        self.direction = direction
        self.opacity = opacity
        self.shape = shape
    }

    private func shapeView() -> AnyShape {
        switch shape {
        case .capsule:
            return AnyShape(Capsule())
        case .roundedRectangle(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius))
        }
    }

    var body: some View {
        let shape = shapeView()
        
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: direction.start(),
                endPoint: direction.end()
            )
            .opacity(opacity)
            .clipShape(shape)
        }
        .overlay(
            shape
                .stroke(
                    LinearGradient(
                        colors: borderColors,
                        startPoint: direction.start(),
                        endPoint: direction.end()
                    ),
                    lineWidth: borderWidth
                )
                .opacity(opacity)
        )
    }
}

struct AnyShape: Shape {
    private let path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        self.path = { rect in shape.path(in: rect) }
    }
    
    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}
