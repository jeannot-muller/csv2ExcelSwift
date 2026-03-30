import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            NavBar()
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    FileInputView()
                    Divider()
                    DelimiterPicker()
                    Divider()
                    SheetNameField()
                    Divider()
                    MetadataSection()
                    Divider()
                    ConvertButton()
                }
                .padding()
            }

            Divider()
            FooterBar()
        }
    }
}
