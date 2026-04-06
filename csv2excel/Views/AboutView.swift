import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    private let year = Calendar.current.component(.year, from: Date())

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("csv2excel")
                .font(.title.bold())

            Text("Version \(version) (\(build))")
                .foregroundStyle(.secondary)
                .font(.callout)

            Text("Convert CSV files to Excel format")
                .foregroundStyle(.secondary)
                .font(.callout)

            Spacer().frame(height: 4)

            Text("© \(String(year)) Jeannot Muller")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 300)
    }
}
