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
            // "2 sort options only... length"
            return [.date, .length]
        } else {
            // "for imported videos show the 4th also by size"
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
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)
            
            // Header
            HStack {
                Text("Sort by")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Done") {
                    applySort()
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Criteria Section
                    VStack(spacing: 0) {
                        ForEach(availableCriteria, id: \.self) { criteria in
                            sortRow(title: criteria.rawValue, isSelected: selectedCriteria == criteria) {
                                withAnimation {
                                    selectedCriteria = criteria
                                }
                            }
                            if criteria != availableCriteria.last {
                                Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
                    .cornerRadius(16)
                    
                    // Order Section
                    VStack(spacing: 0) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            sortRow(title: order.title(for: selectedCriteria), isSelected: selectedOrder == order) {
                                withAnimation {
                                    selectedOrder = order
                                }
                            }
                            if order != SortOrder.allCases.last {
                                Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)).edgesIgnoringSafeArea(.all))
        .onAppear {
            mapCurrentState()
        }
    }
    
    private func sortRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 15))
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.orange : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
