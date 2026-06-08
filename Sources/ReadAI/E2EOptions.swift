import Foundation

struct E2EOptions {
    let statusPath: String?
    let exitAfterOpen: Bool
    let turnPages: Bool
    let readingStyle: String?
    let fontSize: Int?
    let lineSpacing: Int?
    let readerFullscreen: Bool
    let searchQuery: String?
    let addBookmark: Bool
    let addHighlight: Bool
    let addNote: Bool
    let theme: String?
    let keyboard: Bool
    let toggleSettings: Bool
    let clearPosition: Bool
    let openLast: Bool
    let startupBookPath: String?

    static let current = E2EOptions(arguments: CommandLine.arguments)
    static var isRequested: Bool {
        if ProcessInfo.processInfo.environment["READAI_E2E_STATUS_PATH"] != nil {
            return true
        }
        return CommandLine.arguments.contains { argument in
            argument == "--e2e-status-path"
                || argument.hasPrefix("--e2e-status-path=")
        }
    }

    init(arguments: [String]) {
        var statusPath: String?
        var exitAfterOpen = false
        var turnPages = false
        var readingStyle: String?
        var fontSize: Int?
        var lineSpacing: Int?
        var readerFullscreen = false
        var searchQuery: String?
        var addBookmark = false
        var addHighlight = false
        var addNote = false
        var theme: String?
        var keyboard = false
        var toggleSettings = false
        var clearPosition = false
        var openLast = false
        var startupBookPath: String?
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]

            if argument == "--e2e-exit-after-open" {
                exitAfterOpen = true
                index += 1
                continue
            }

            if argument == "--e2e-turn-pages" {
                turnPages = true
                index += 1
                continue
            }

            if argument == "--e2e-reader-fullscreen" {
                readerFullscreen = true
                index += 1
                continue
            }

            if argument == "--e2e-add-bookmark" {
                addBookmark = true
                index += 1
                continue
            }

            if argument == "--e2e-add-highlight" {
                addHighlight = true
                index += 1
                continue
            }

            if argument == "--e2e-add-note" {
                addNote = true
                index += 1
                continue
            }

            if argument == "--e2e-keyboard" {
                keyboard = true
                index += 1
                continue
            }

            if argument == "--e2e-toggle-settings" {
                toggleSettings = true
                index += 1
                continue
            }

            if argument == "--e2e-clear-position" {
                clearPosition = true
                index += 1
                continue
            }

            if argument == "--e2e-open-last" {
                openLast = true
                index += 1
                continue
            }

            if argument == "--e2e-reading-style", index + 1 < arguments.count {
                readingStyle = arguments[index + 1]
                index += 2
                continue
            }

            if argument == "--e2e-font-size", index + 1 < arguments.count {
                fontSize = Int(arguments[index + 1])
                index += 2
                continue
            }

            if argument == "--e2e-line-spacing", index + 1 < arguments.count {
                lineSpacing = Int(arguments[index + 1])
                index += 2
                continue
            }

            if argument == "--e2e-search", index + 1 < arguments.count {
                searchQuery = arguments[index + 1]
                index += 2
                continue
            }

            if argument == "--e2e-theme", index + 1 < arguments.count {
                theme = arguments[index + 1]
                index += 2
                continue
            }

            if argument == "--e2e-status-path", index + 1 < arguments.count {
                statusPath = arguments[index + 1]
                index += 2
                continue
            }

            if argument.hasPrefix("--e2e-status-path=") {
                statusPath = String(argument.dropFirst("--e2e-status-path=".count))
                index += 1
                continue
            }

            if !argument.hasPrefix("--"), startupBookPath == nil {
                startupBookPath = argument
            }
            index += 1
        }

        self.statusPath = ProcessInfo.processInfo.environment["READAI_E2E_STATUS_PATH"] ?? statusPath
        self.exitAfterOpen = ProcessInfo.processInfo.environment["READAI_E2E_EXIT_AFTER_OPEN"] == "1" || exitAfterOpen
        self.turnPages = turnPages
        self.readingStyle = readingStyle
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.readerFullscreen = readerFullscreen
        self.searchQuery = searchQuery
        self.addBookmark = addBookmark
        self.addHighlight = addHighlight
        self.addNote = addNote
        self.theme = theme
        self.keyboard = keyboard
        self.toggleSettings = toggleSettings
        self.clearPosition = clearPosition
        self.openLast = openLast
        self.startupBookPath = startupBookPath
    }
}
