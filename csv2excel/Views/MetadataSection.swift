import SwiftUI

struct MetadataSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        DisclosureGroup {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Title")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxTitle)
                        .textFieldStyle(.roundedBorder)
                    Text("Subject")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxSubject)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Author")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxAuthor)
                        .textFieldStyle(.roundedBorder)
                    Text("Manager")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxManager)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Company")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxCompany)
                        .textFieldStyle(.roundedBorder)
                    Text("Category")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxCategory)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Keywords")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxKeywords)
                        .textFieldStyle(.roundedBorder)
                    Text("Comment")
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("", text: $state.xlsxComment)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 4) {
                Text("EXCEL METADATA")
                Text("(optional)")
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
