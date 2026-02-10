import SwiftUI

struct SleepTimerSheetView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    var onBack: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            if !isLandscape {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            
            header
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    timerOptionsCard
                    
                    if viewModel.isSleepTimerActive {
                        turnOffCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .applyIf(isLandscape) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .bottomLeft])
        }
        .applyIf(!isLandscape) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .topRight])
        }
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: isLandscape ? 0 : -10)
    }
    
    private var header: some View {
        HStack {
            Button(action: {
                if let onBack = onBack {
                    onBack()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.premiumCircleBackground)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Sleep Timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                if let remaining = viewModel.sleepTimerRemainingString, viewModel.isSleepTimerActive {
                    Text(remaining)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Invisible spacer to balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, isLandscape ? 16 : 0)
        .padding(.bottom, 20)
    }
    
    private var timerOptionsCard: some View {
        VStack(spacing: 0) {
            timerOptionItem(minutes: 5)
            divider
            timerOptionItem(minutes: 10)
            divider
            timerOptionItem(minutes: 15)
            divider
            timerOptionItem(minutes: 30)
            divider
            timerOptionItem(minutes: 45)
            divider
            timerOptionItem(minutes: 60)
            divider
            endOfTrackItem
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.premiumCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
    }
    
    private var turnOffCard: some View {
        Button(action: {
            viewModel.cancelSleepTimer()
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }) {
            HStack {
                Text("Turn off timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red.opacity(0.9))
                Spacer()
                Image(systemName: "power")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private func timerOptionItem(minutes: Int) -> some View {
        let isSelected = isTimerSet(minutes: minutes)
        
        return Button(action: {
            viewModel.startSleepTimer(minutes: minutes)
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }) {
            HStack {
                Text("\(minutes) minutes")
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .orange : .white)
                
                Spacer()
                
                customRadioButton(isSelected: isSelected)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
    }
    
    private var endOfTrackItem: some View {
        let isSelected = (viewModel.sleepTimerMode == .endOfTrack)
        
        return Button(action: {
            viewModel.setSleepTimerEndOfTrack()
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }) {
            HStack {
                Text("End of track")
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .orange : .white)
                
                Spacer()
                
                customRadioButton(isSelected: isSelected)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
    }
    
    private func customRadioButton(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.orange : Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 20, height: 20)
            
            if isSelected {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
            }
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.premiumCardBackground)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
    
    private func isTimerSet(minutes: Int) -> Bool {
        if let original = viewModel.sleepTimerOriginalDuration {
            return original == TimeInterval(minutes * 60)
        }
        return false
    }
}
