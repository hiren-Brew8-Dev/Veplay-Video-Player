import SwiftUI

struct CustomSortingView: View {
    @Binding var sortOptionRaw: String
    var title: String = "" // Context identifier
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCriteria: SortCriteria = .date
    @State private var selectedOrder: SortOrder = .descending
    
    enum SortCriteria: String, CaseIterable {
        case date = "Date"
        case length = "Length"
        case size = "Size"
        case name = "Name"
    }
    
    // Computed property to filter criteria
    var availableCriteria: [SortCriteria] {
        if title == "History" {
            return [.date, .length]
        } else if title == "Album" || title == "Gallery" {
            return [.date, .name, .length]
        } else {
            return [.date, .name, .length, .size]
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case descending
        case ascending
        
        func title(for criteria: SortCriteria) -> String {
            switch criteria {
            case .date: return self == .descending ? "From new to old" : "From old to new"
            case .length: return self == .descending ? "From long to short" : "From short to long"
            case .size: return self == .descending ? "From large to small" : "From small to large"
            case .name: return self == .ascending ? "From A to Z" : "From Z to A"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Header
            HStack {
                Text("Sort by")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    applySort()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Criteria Section
                    VStack(spacing: 0) {
                        ForEach(Array(availableCriteria.enumerated()), id: \.element.self) { index, criteria in
                            sortRow(title: criteria.rawValue, isSelected: selectedCriteria == criteria) {
                                withAnimation {
                                    selectedCriteria = criteria
                                }
                            }
                            if index < availableCriteria.count - 1 {
                                divider
                            }
                        }
                    }
                    .background(Color.premiumCardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.premiumCardBorder, lineWidth: 1)
                    )
                    
                    // Order Section
                    VStack(spacing: 0) {
                        ForEach(Array(SortOrder.allCases.enumerated()), id: \.element.self) { index, order in
                            sortRow(title: order.title(for: selectedCriteria), isSelected: selectedOrder == order) {
                                withAnimation {
                                    selectedOrder = order
                                }
                            }
                            if index < SortOrder.allCases.count - 1 {
                                divider
                            }
                        }
                    }
                    .background(Color.premiumCardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.premiumCardBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadiusLocal(28, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: -10)
        .onAppear {
            mapCurrentState()
        }
    }
    
    private func sortRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(isSelected ? .orange : .white)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.premiumCardBorder)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
    
    func mapCurrentState() {
        switch sortOptionRaw {
        case "Newest First": selectedCriteria = .date; selectedOrder = .descending
        case "Oldest First": selectedCriteria = .date; selectedOrder = .ascending
        case "Name (A-Z)": selectedCriteria = .name; selectedOrder = .ascending
        case "Name (Z-A)": selectedCriteria = .name; selectedOrder = .descending
        case "Size (Large to Small)": selectedCriteria = .size; selectedOrder = .descending
        case "Size (Small to Large)": selectedCriteria = .size; selectedOrder = .ascending
        case "Duration (Long to Short)": selectedCriteria = .length; selectedOrder = .descending
        case "Duration (Short to Long)": selectedCriteria = .length; selectedOrder = .ascending
        default: 
            selectedCriteria = .date
            selectedOrder = .descending
        }
    }
    
    func applySort() {
        switch selectedCriteria {
        case .date:
            sortOptionRaw = (selectedOrder == .descending) ? "Newest First" : "Oldest First"
        case .name:
            sortOptionRaw = (selectedOrder == .ascending) ? "Name (A-Z)" : "Name (Z-A)"
        case .size:
            sortOptionRaw = (selectedOrder == .descending) ? "Size (Large to Small)" : "Size (Small to Large)"
        case .length:
            sortOptionRaw = (selectedOrder == .descending) ? "Duration (Long to Short)" : "Duration (Short to Long)"
        }
    }
}
