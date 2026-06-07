import AppKit
import SwiftUI

struct ReadAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Book...") {
                    model.showOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            NotificationCenter.default.post(
                name: .readAIOpenFile,
                object: URL(fileURLWithPath: filename)
            )
        }
        sender.reply(toOpenOrPrint: .success)
    }
}

extension Notification.Name {
    static let readAIOpenFile = Notification.Name("readAIOpenFile")
}
