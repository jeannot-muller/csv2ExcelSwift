import SwiftUI

struct BatchFileListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Batch Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(appState.batchFiles.count) files")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(appState.batchFiles.enumerated()), id: \.element.id) { idx, file in
                        HStack(spacing: 8) {
                            statusIcon(for: file.status)
                            Text(file.name)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            statusLabel(for: file.status)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(idx % 2 == 0 ? Color.primary.opacity(0.03) : .clear)
                    }
                }
            }
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
            .padding(.horizontal, 20)
            .frame(maxHeight: 120)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func statusIcon(for status: BatchFile.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
                .font(.caption2)
        case .converting:
            ProgressView()
                .controlSize(.mini)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption2)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption2)
        }
    }

    @ViewBuilder
    private func statusLabel(for status: BatchFile.Status) -> some View {
        switch status {
        case .pending:
            EmptyView()
        case .converting:
            Text("Converting...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .done(let duration):
            Text(duration)
                .font(.caption2)
                .foregroundStyle(.green)
        case .error(let message):
            Text(message)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}
