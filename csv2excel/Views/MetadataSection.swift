import SwiftUI

struct MetadataSection: View {
    @Environment(AppState.self) private var appState
    @State private var showEditor = false

    private var filledFields: [(String, String)] {
        [
            ("Title", appState.xlsxTitle),
            ("Subject", appState.xlsxSubject),
            ("Author", appState.xlsxAuthor),
            ("Manager", appState.xlsxManager),
            ("Company", appState.xlsxCompany),
            ("Category", appState.xlsxCategory),
            ("Keywords", appState.xlsxKeywords),
            ("Comment", appState.xlsxComment),
        ]
        .filter { !$0.1.isEmpty }
    }

    var body: some View {
        if filledFields.isEmpty {
            HStack {
                Text("None set")
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Edit\u{2026}") { showEditor = true }
            }
        } else {
            ForEach(filledFields, id: \.0) { label, value in
                LabeledContent(label) {
                    Text(value)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Clear All", role: .destructive) {
                    appState.clearMetadata()
                }
                .font(.callout)
                Spacer()
                Button("Edit\u{2026}") { showEditor = true }
            }
        }
        EmptyView()
            .sheet(isPresented: $showEditor) {
                appState.save()
            } content: {
                MetadataEditorSheet()
                    .environment(appState)
            }
    }
}

struct MetadataEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showPresets = false

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            Form {
                Section("Document Properties") {
                    LabeledContent("Title") { TextField("", text: $state.xlsxTitle, prompt: Text("Title")).textFieldStyle(.roundedBorder) }
                    LabeledContent("Subject") { TextField("", text: $state.xlsxSubject, prompt: Text("Subject")).textFieldStyle(.roundedBorder) }
                    LabeledContent("Author") { TextField("", text: $state.xlsxAuthor, prompt: Text("Author")).textFieldStyle(.roundedBorder) }
                    LabeledContent("Manager") { TextField("", text: $state.xlsxManager, prompt: Text("Manager")).textFieldStyle(.roundedBorder) }
                    LabeledContent("Company") { TextField("", text: $state.xlsxCompany, prompt: Text("Company")).textFieldStyle(.roundedBorder) }
                    LabeledContent("Category") { TextField("", text: $state.xlsxCategory, prompt: Text("Category")).textFieldStyle(.roundedBorder) }
                    LabeledContent("Keywords") { TextField("", text: $state.xlsxKeywords, prompt: Text("Keywords")).textFieldStyle(.roundedBorder) }
                    LabeledContent("Comment") { TextField("", text: $state.xlsxComment, prompt: Text("Comment")).textFieldStyle(.roundedBorder) }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button {
                    showPresets = true
                } label: {
                    Label("Presets", systemImage: "doc.on.doc")
                }
                .popover(isPresented: $showPresets) {
                    MetadataPresetView()
                        .environment(appState)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 420)
    }
}
