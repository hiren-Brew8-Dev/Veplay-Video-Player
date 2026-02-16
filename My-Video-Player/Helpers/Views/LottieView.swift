//
//  LottieView.swift
//  AR-Tattoo
//
//  Created by Shivshankar T Tiwari on 03/12/25.
//

import SwiftUI
import Lottie

enum LottiePlayback {
    case play
    case pause
    case stop
}

struct LottieView: UIViewRepresentable {

    let animationName: String
    let playback: LottiePlayback
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = contentMode
        
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.shouldRasterizeWhenIdle = true
        animationView.animationSpeed = 1

        container.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: container.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: container.heightAnchor),
            animationView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        context.coordinator.animationView = animationView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        let animationView = coordinator.animationView

        // 🔄 Animation change
        if coordinator.currentAnimationName != animationName {
            coordinator.currentAnimationName = animationName
            animationView?.animation = LottieAnimation.named(animationName)
        }

        // ▶️ Playback control
        switch playback {
        case .play:
            animationView?.loopMode = loopMode
            if animationView?.isAnimationPlaying == false {
                animationView?.play { finished in
                    if finished && loopMode == .playOnce {
                        animationView?.pause()
                    }
                }
            }

        case .pause:
            animationView?.pause()

        case .stop:
            animationView?.stop()
            animationView?.currentProgress = 0
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var animationView: LottieAnimationView?
        var currentAnimationName: String?
    }
}
