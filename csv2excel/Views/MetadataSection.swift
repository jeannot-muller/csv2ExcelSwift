import SwiftUI

struct MetadataSection: View {
    @Environment(AppState.self) private var appState
    @State private var showPresets = false

    private var headerColorBinding: Binding<Color> {
        Binding(
            get: { appState.headerColor.isEmpty ? .accentColor : Color(hex: appState.headerColor) },
            set: { appState.headerColor = $0.hexString ?? ""; appState.save() }
        )
    }

    private var tabColorBinding: Binding<Color> {
        Binding(
            get: { appState.sheetTabColor.isEmpty ? .accentColor : Color(hex: appState.sheetTabColor) },
            set: { appState.sheetTabColor = $0.hexString ?? ""; appState.save() }
        )
    }

    var body: some View {
        @Bindable var state = appState

        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                metadataField("Title", $state.xlsxTitle)
                metadataField("Author", $state.xlsxAuthor)
                metadataField("Company", $state.xlsxCompany)
                metadataField("Keywords", $state.xlsxKeywords)
                colorRow("Header", headerColorBinding, appState.headerColor) {
                    appState.headerColor = ""
                    appState.save()
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                metadataField("Subject", $state.xlsxSubject)
                metadataField("Manager", $state.xlsxManager)
                metadataField("Category", $state.xlsxCategory)
                metadataField("Comment", $state.xlsxComment)
                colorRow("Tab", tabColorBinding, appState.sheetTabColor) {
                    appState.sheetTabColor = ""
                    appState.save()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .popover(isPresented: $showPresets) {
            MetadataPresetView()
                .environment(appState)
        }
    }

    private func metadataField(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            TextField("", text: binding, prompt: Text(label))
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .onChange(of: binding.wrappedValue) { appState.save() }
        }
    }

    private func colorRow(_ label: String, _ binding: Binding<Color>, _ hex: String, clear: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label) color")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack(spacing: 4) {
                ColorPicker("", selection: binding, supportsOpacity: false)
                    .labelsHidden()
                if !hex.isEmpty {
                    Button(action: clear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }
}
