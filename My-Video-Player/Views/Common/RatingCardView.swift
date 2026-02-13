//
//  RatingCardView.swift
//  My-Video-Player
//

import SwiftUI

struct RatingCardView: View {
    var isFromSettings: Bool = false
    
    var body: some View {
        GradientBorderView(
            borderColors: [.clear],
            backgroundColors: [.gray.opacity(0.01), .gray.opacity(0.05), .gray.opacity(0.01)],
            borderWidth: 3,
            direction: .angle(50),
            shape: .roundedRectangle(20)
        )
        .aspectRatio(isIpad ? 361/125 : 361/175, contentMode: .fit)
        .overlay {
            ZStack {
                // Background with slight glow
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "F9B041").opacity(0.1))
                
                RatingCardContentView(isFromSettings: .constant(isFromSettings))
                    .padding(isIpad ? 22 : 17)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct RatingCardContentView: View {
    @Binding var isFromSettings: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    Image(systemName: "star.bubble.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: "F9B041"))
                    
                    Text("Enjoying the App?")
                        .foregroundStyle(.white)
                        .appFont(.manropeBold, size: 18)
                }
                
                Spacer()
                
                Button {
                    HapticsManager.shared.generate(.soft)
                    withAnimation {
                        AppReviewManager.shared.snoozeRatingCard()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(8)
                }
            }
            
            Text("Your review helps us grow! Help others know\nyour experience!")
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white.opacity(0.8))
                .appFont(.manropeMedium, size: 16)
            
            HStack(spacing: 14) {
                Spacer()
                
                Button {
                    HapticsManager.shared.generate(.soft)
                    withAnimation {
                        AppReviewManager.shared.hideRatingCardForever()
                    }
                } label: {
                    Text("Not interested")
                        .foregroundStyle(.white.opacity(0.6))
                        .appFont(.manropeMedium, size: 14)
                }
                
                CustomTextButton(
                    title: "Rate Now",
                    aspectRatio: 112/35,
                    iphoneWidth: 112,
                    ipadWidth: 80,
                    foregroundColor: .black,
                    backgroundColor: Color(hex: "F9B041"),
                    cornerRadius: 10,
                    font: .manropeBold,
                    iphoneFontSize: 14
                ) {
                    if !isFromSettings {
                        withAnimation {
                            AppReviewManager.shared.submitReview(isShowAppleReviewScreen: true)
                            AppReviewManager.shared.ratingPopupViewViewedSet()
                        }
                    } else {
                        AppReviewManager.shared.openAppStoreReview()
                    }
                }
            }
        }
    }
}
