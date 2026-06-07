import SwiftUI
import WebKit

struct EPUBReaderView: NSViewRepresentable {
    let chapter: EPUBChapter

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        load(chapter, in: view, context: context)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loadedChapterID != chapter.id else { return }
        load(chapter, in: view, context: context)
    }

    private func load(_ chapter: EPUBChapter, in view: WKWebView, context: Context) {
        context.coordinator.loadedChapterID = chapter.id
        view.loadHTMLString(wrappedHTML(chapter.html), baseURL: chapter.baseURL)
    }

    private func wrappedHTML(_ body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 0 auto;
              max-width: 760px;
              padding: 44px 56px 80px;
              font: 18px/1.65 -apple-system, BlinkMacSystemFont, "New York", serif;
              color: -apple-system-label;
              background: -apple-system-text-background;
            }
            img, svg, video { max-width: 100%; height: auto; }
            pre { white-space: pre-wrap; }
            a { color: -apple-system-link; }
          </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    final class Coordinator {
        var loadedChapterID: UUID?
    }
}
