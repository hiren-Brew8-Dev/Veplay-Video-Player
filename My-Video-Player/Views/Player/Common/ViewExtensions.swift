import SwiftUI

extension View {
    func cornerRadiusLocal(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCornerLocal(radius: radius, corners: corners) )
    }
}

struct RoundedCornerLocal: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension Array {
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let itemsToMove = source.map { self[$0] }
        for (index, oldIndex) in source.enumerated() {
            self.remove(at: oldIndex - index)
        }
        let targetIndex = destination > self.count ? self.count : (destination < 0 ? 0 : destination)
        self.insert(contentsOf: itemsToMove, at: targetIndex)
    }
}
