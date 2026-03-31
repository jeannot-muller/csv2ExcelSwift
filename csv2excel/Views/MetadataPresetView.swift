import SwiftUI

struct MetadataPresetView: View {
    @Environment(AppState.self) private var appState
    @State private var newPresetName = ""
    @State private var showDeleteAllConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata Presets")
                .font(.headline)

            if appState.metadataPresets.isEmpty {
                Text("No saved presets")
                    .foregroundStyle(.tertiary)
                    .font(.callout)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(appState.metadataPresets.enumerated()), id: \.element.id) { _, preset in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(preset.name)
                                        .font(.callout)
                                    Text(presetSummary(preset))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("Apply") {
                                    appState.applyMetadataPreset(preset)
                                    dismiss()
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                                .font(.callout)
                                Button {
                                    appState.metadataPresets.removeAll { $0.id == preset.id }
                                    appState.save()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            Divider()

            HStack {
                TextField("Preset name", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                Button("Save Current") {
                    guard !newPresetName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let preset = appState.createMetadataPreset(name: newPresetName.trimmingCharacters(in: .whitespaces))
                    appState.metadataPresets.append(preset)
                    appState.save()
                    newPresetName = ""
                    dismiss()
                }
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !appState.metadataPresets.isEmpty {
                Button("Delete All Presets", role: .destructive) {
                    showDeleteAllConfirmation = true
                }
                .font(.callout)
                .confirmationDialog(
                    "Delete all metadata presets?",
                    isPresented: $showDeleteAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) {
                        appState.metadataPresets.removeAll()
                        appState.save()
                    }
                } message: {
                    Text("This will permanently remove all saved metadata presets.")
                }
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func presetSummary(_ preset: MetadataPreset) -> String {
        [preset.xlsxAuthor, preset.xlsxCompany, preset.xlsxTitle]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }
}
