import SwiftUI

struct MetadataSection: View {
    @Environment(AppState.self) private var appState
    @State private var showPresets = false

    private var headerColorBinding: Binding<Color> {
        Binding(
            get: { appState.headerColor.isEmpty ? .clear : Color(hex: appState.headerColor) },
            set: { appState.headerColor = $0.hexString ?? ""; appState.save() }
        )
    }

    private var tabColorBinding: Binding<Color> {
        Binding(
            get: { appState.sheetTabColor.isEmpty ? .clear : Color(hex: appState.sheetTabColor) },
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
                colorRow("Excel Header", headerColorBinding, appState.headerColor, defaultColor: Self.defaultHeaderColor) {
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
                colorRow("Excel Tab", tabColorBinding, appState.sheetTabColor, defaultColor: Self.defaultTabColor) {
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

    private static let defaultHeaderColor = Color(red: 0.66, green: 0.83, blue: 0.96)  // Light blue
    private static let defaultTabColor = Color(red: 0.5, green: 0.3, blue: 0.7)      // Purple

    private func colorRow(_ label: String, _ binding: Binding<Color>, _ hex: String, defaultColor: Color, clear: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label) color")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack(spacing: 4) {
                if hex.isEmpty {
                    Button("Choose…") {
                        binding.wrappedValue = defaultColor
                    }
                    .controlSize(.small)
                } else {
                    ColorPicker("", selection: binding, supportsOpacity: false)
                        .labelsHidden()
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
