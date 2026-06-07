import Foundation

struct E2EOptions {
    let statusPath: String?
    let exitAfterOpen: Bool
    let startupBookPath: String?

    static let current = E2EOptions(arguments: CommandLine.arguments)

    init(arguments: [String]) {
        var statusPath: String?
        var exitAfterOpen = false
        var startupBookPath: String?
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]

            if argument == "--e2e-exit-after-open" {
                exitAfterOpen = true
                index += 1
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
        self.startupBookPath = startupBookPath
    }
}
