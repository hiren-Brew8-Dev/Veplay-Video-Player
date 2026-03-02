import SwiftUI

struct ImportingOverlay: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        if viewModel.isImporting {
            ZStack {
                Color.homeBackground.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                
                if isIpad {
                    importingContent
                } else {
                    VStack {
                        Spacer()
                        importingContent
                        Spacer()
                    }
                }
            }
            .zIndex(100)
        }
    }

    private var importingContent: some View {
        VStack(spacing: 28) {
            // UI Header
            VStack(spacing: 8) {
                Text("Importing Videos")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                if viewModel.importCount > 1 {
                    Text("Processing \(viewModel.importCurrentIndex) of \(viewModel.importCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Progress Circle/Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: viewModel.importProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.homeAccent, .homeAccent.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: viewModel.importProgress)
                
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.importProgress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Complete")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Status Message + Spinner
            VStack(spacing: 12) {
                Text(viewModel.importStatusMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 44)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .homeAccent))
                    .scaleEffect(0.8)
            }
            .padding(.horizontal, 20)
            
            // Cancel Button — stops copying remaining files; already-imported files are kept
            Button(action: {
                HapticsManager.shared.generate(.medium)
                viewModel.cancelImport()
            }) {
                Text(viewModel.isImportCancelled ? "Cancelling…" : "Cancel Import")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(viewModel.isImportCancelled ? .white.opacity(0.4) : .red)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.07))
                    )
            }
            .disabled(viewModel.isImportCancelled)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
        .frame(width: 320) // Fixed width before background to stabilize size
        .background(
            AppGlobalBackground()
                .clipShape(RoundedRectangle(cornerRadius: 32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.premiumCardBorder, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 40, x: 0, y: 20)
    }
}
