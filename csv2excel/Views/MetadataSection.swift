import SwiftUI

struct MetadataSection: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false

    var body: some View {
        @Bindable var state = appState

        DisclosureGroup(isExpanded: $isExpanded) {
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 10) {
                metadataRow("Title", $state.xlsxTitle, "Subject", $state.xlsxSubject)
                metadataRow("Author", $state.xlsxAuthor, "Manager", $state.xlsxManager)
                metadataRow("Company", $state.xlsxCompany, "Category", $state.xlsxCategory)
                metadataRow("Keywords", $state.xlsxKeywords, "Comment", $state.xlsxComment)
            }
            .padding(.top, 4)
        } label: {
            Text("Excel metadata (optional)")
        }
    }

    private func metadataRow(
        _ label1: String, _ binding1: Binding<String>,
        _ label2: String, _ binding2: Binding<String>
    ) -> some View {
        GridRow {
            Text(label1)
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .trailing)
            TextField(label1, text: binding1)
                .textFieldStyle(.roundedBorder)
            Text(label2)
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .trailing)
            TextField(label2, text: binding2)
                .textFieldStyle(.roundedBorder)
        }
    }
}
