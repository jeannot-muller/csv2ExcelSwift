import SwiftUI

struct PresetManagerView: View {
    @Environment(AppState.self) private var appState
    @State private var newPresetName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)

            if appState.presets.isEmpty {
                Text("No saved presets")
                    .foregroundStyle(.tertiary)
                    .font(.callout)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        let presets = appState.presets
                        ForEach(Array(presets.enumerated()), id: \.element.id) { _, preset in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(preset.name)
                                        .font(.callout)
                                    Text("\(preset.sheetName) / \(preset.encoding) / \(preset.delimiter)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Apply") {
                                    appState.applyPreset(preset)
                                    dismiss()
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                                .font(.callout)
                                Button {
                                    appState.presets.removeAll { $0.id == preset.id }
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
                    let preset = appState.createPreset(name: newPresetName.trimmingCharacters(in: .whitespaces))
                    appState.presets.append(preset)
                    appState.save()
                    newPresetName = ""
                }
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }
}
