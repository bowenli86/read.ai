import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var apiKey = ""

    var body: some View {
        Form {
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            TextField("Base URL", text: $model.baseURL)
                .textFieldStyle(.roundedBorder)

            TextField("Model", text: $model.modelName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Save") {
                    model.apiKey = apiKey
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 480)
        .onAppear {
            apiKey = model.apiKey
        }
    }
}
