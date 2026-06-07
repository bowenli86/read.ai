import Foundation
import PDFKit

struct AppAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct Book: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let content: BookContent

    var kind: String {
        switch content {
        case .pdf:
            return "pdf"
        case .epub:
            return "epub"
        }
    }

    var chapterCount: Int {
        switch content {
        case .pdf:
            return 0
        case .epub(let epub):
            return epub.chapters.count
        }
    }
}

enum BookContent {
    case pdf(PDFBook)
    case epub(EPUBBook)
}

struct PDFBook {
    let document: PDFDocument
    let text: String
}

struct EPUBBook {
    let title: String
    let chapters: [EPUBChapter]
}

struct EPUBChapter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let html: String
    let text: String
    let baseURL: URL
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: ChatRole
    let text: String
}

enum ChatRole: String {
    case user
    case assistant
}

struct ReadAIError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
