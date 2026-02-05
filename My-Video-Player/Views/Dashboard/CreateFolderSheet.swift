import SwiftUI

struct CreateFolderSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: DashboardViewModel
    @State private var folderName: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Folder Details")) {
                    TextField("Folder Name", text: $folderName)
                }
            }
            .navigationBarTitle("New Folder", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    viewModel.createFolder(name: folderName)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(folderName.isEmpty)
            )
        }
    }
}
