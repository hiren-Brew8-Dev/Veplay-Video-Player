//
//  RatingCardView.swift
//  My-Video-Player
//

import SwiftUI

struct CustomRatingPopup: View {
    
    @State var ratedStars : Int = 0
    
    // Animation states
    @State private var showPopup = false
    @State private var showHeader = false
    @State private var showText = false
    @State private var showStars = false
    @State private var showButton = false
    
    @State private var heartShake: CGFloat = 0
    @State private var heartDrop: CGFloat = 0
    @State private var smileBounce: CGFloat = 1
    @State private var imageOpacity: Double = 1
    
    @State private var lastEmotion: Emotion = .neutral
    

    enum Emotion {
        case neutral
        case sad
        case happy
    }
    
    private var isLowRating: Bool {
        ratedStars > 0 && ratedStars <= 3
    }
    
    private var headerImage: ImageResource {
        isLowRating ? .rateHeartFail : .rateSmile
    }
    
    private var currentEmotion: Emotion {
        switch ratedStars {
        case 1...3:
            return .sad
        case 4...5:
            return .happy
        default:
            return .neutral
        }
    }
    
    private var buttonTitle: String {
        switch ratedStars {
        case 0:
            return "Submit"
        case 1...3:
            return "Write a Review"
        default:
            return "Submit"
        }
    }
    
    private var titleText: String {
        switch ratedStars {
        case 1...3:
            return "Help Us Get Better"
        case 4...5:
            return "Your words matter\nmore than you think"
        default:
            return "Your words matter\nmore than you think"
        }
    }

    private var subtitleText: String {
        switch ratedStars {
        case 1...3:
            return "Tell us what didn’t work so we can\nimprove the game."
        case 4...5:
            return "Appreciate the rating. Let’s\nkeep the fun rolling."
        default:
            return "Appreciate the rating. Let’s\nkeep the fun rolling."
        }
    }
    
    private var lottieAnimationName: String {
        switch ratedStars {
        case 1...3:
            return LottieNames.rate3_or_less_star.rawValue
        default:
            return LottieNames.rate4_or_5_start.rawValue
        }
    }
    
    var body: some View {
        
        ZStack {
            GradientBorderView(borderColors: [.white.opacity(0.2)], backgroundColors: [Color(hex: "#0B0B0FE")], shape: .roundedRectangle(32))
                .overlay {
                    VStack (spacing: 0){
                        ZStack (alignment: .top) {
                            LottieView(animationName: lottieAnimationName, playback: .play)
                                .aspectRatio(1, contentMode: .fit)
                                .responsiveWidth(iphoneWidth: 0.31, ipadWidth: 0.21)
                                
                                .opacity(imageOpacity)
                                
                                .animation(.easeInOut(duration: 0.25), value: ratedStars)
                                .onChange(of: ratedStars) { _ in
                                    guard currentEmotion != lastEmotion else { return }
                                    
                                    lastEmotion = currentEmotion
                                    triggerEmotionAnimation(for: ratedStars)
                                }
                            
                            HStack {
                                Spacer()
                                CustomButton(image: .closePaywall) {
                                    RatingFlowViewModel.shared.customRatingDismiss()
                                }
                                .responsiveWidth(iphoneWidth: 0.07, ipadWidth: 0.05)
                                
                            }
                        }
                        
                        Text(titleText)
                            .appFont(.manropeBold, size: 20)
                            .minimumScaleFactor(0.3)
                            .padding(.bottom, 8)
                            .multilineTextAlignment(.center)
                            .opacity(showText ? 1 : 0)
                            .offset(y: showText ? 0 : 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.easeInOut(duration: 0.25), value: ratedStars)

                        
                        Text(subtitleText)
                            .multilineTextAlignment(.center)
                            .appFont(.manropeRegular, size: 15)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineSpacing(4)
                            .minimumScaleFactor(0.3)
                            .opacity(showText ? 1 : 0)
                            .offset(y: showText ? 0 : 15)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.easeInOut(duration: 0.3).delay(0.05), value: ratedStars)

                        
                        Spacer()
                        
                        StarRatingView(ratedStars: $ratedStars, animate: showStars)
                            .responsivePadding(edge: .vertical, fraction: 0.015)
                            .responsivePadding(edge: .bottom, fraction: 0.01)
                            
                        
                        CustomTextButton(title: buttonTitle, aspectRatio: 200/44, iphoneWidth: 0.55, ipadWidth: 0.36,foregroundColor: ratedStars == 0 ? Color(hex: "#828282") : .black, backgroundColor: ratedStars == 0 ? .white.opacity(0.1) : .white, font: .manropeSemiBold) {
                            
                            RatingFlowViewModel.shared.submitStars(stars: ratedStars)
                            RatingFlowViewModel.shared.isAlreadyShown
                            
                        }
                        .opacity(showButton ? 1 : 0)
                        .offset(y: showButton ? 0 : 30)
                        .animation(.easeOut(duration: 0.5), value: showButton)
                        .disabled(ratedStars == 0)
                    
                    }
                    .padding(isIpad ? 35 : 25)
                    
                }
                
        }
        .aspectRatio(289/345, contentMode: .fit)
        .responsiveWidth(iphoneWidth: 0.82, ipadWidth: 0.54)
        .cornerRadius(32)
        .shadow(radius: 20)
        .scaleEffect(showPopup ? 1 : 0.85)
        .opacity(showPopup ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showPopup)
        .onAppear {
            startSequence()

        }
        
    }
    
    func triggerEmotionAnimation(for rating: Int) {

        imageOpacity = 0
        heartShake = 0
        heartDrop = 0
        smileBounce = 1

        // Cross-fade image
        withAnimation(.easeInOut(duration: 0.15)) {
            imageOpacity = 1
        }

        if rating <= 3 {
            // 💔 SAD — Disappointed Feel
            withAnimation(.spring(response: 0.35, dampingFraction: 0.4)) {
                heartShake = -10
                heartDrop = 6
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.4)) {
                    heartShake = 10
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    heartShake = 0
                    heartDrop = 10   // gravity / sadness
                }
            }

            HapticsManager.shared.generate(.light)

        } else {
            // 😊 HAPPY — Delight Feel
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                smileBounce = 1.15
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    smileBounce = 1
                }
            }

            HapticsManager.shared.generate(.soft)
        }
    }

    
    func startSequence() {
        withAnimation { showPopup = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showHeader = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showText = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showStars = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showButton = true
        }
    }

    
    func openMail() {
        let email = "ishivshankartiwari70@gmail.com"
        let subject = ""
        let body = ""

        let urlString =
            "mailto:\(email)" +
            "?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
            "&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    
    func openAppStoreReview() {
        let appID = Global.shared.appID
        let urlString = "https://apps.apple.com/app/id\(appID)?action=write-review"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    
}

struct StarRatingView: View {
    
    @Binding var ratedStars: Int
    let animate: Bool
    
    private let count = 5
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...count, id: \.self) { index in
                Image(index <= ratedStars ? .ratingFill : .ratingUnfill)
                    .resizable()
                    .scaledToFit()
                    .responsiveWidth(iphoneWidth: 0.07, ipadWidth: 0.05)
                    .scaleEffect(index <= ratedStars ? 1.2 : 1)
                    .opacity(animate ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                        .delay(Double(index) * 0.06),
                        value: ratedStars
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            ratedStars = index
                        }
                        HapticsManager.shared.generate(.light)
                    }
            }
        }
    }
}


struct CustomRatingPopupTemp : View {
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            CustomRatingPopup()
        }
    }
}

struct RatingPopupOverlay: View {

    @State private var show = false

    var body: some View {
        ZStack {

            // 🌑 Background dim
            Color.white
                .opacity(show ? 0.32 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: show)

            // 🔍 Zoom popup
            CustomRatingPopup()
                .scaleEffect(show ? 1 : 0.75)
                .opacity(show ? 1 : 0)
                .blur(radius: show ? 0 : 8)
                .animation(
                    .spring(
                        response: 0.45,
                        dampingFraction: 0.85,
                        blendDuration: 0.3
                    ),
                    value: show
                )
        }
        .onAppear {
            // micro-delay = more premium feel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                show = true
            }
        }
    }
}

#Preview {
    RatingPopupOverlay()
}
