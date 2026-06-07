# ReadAI

Native macOS reading app with a hideable left library, center reading pane, and right AI chat pane.

## Features

- PDF reading via PDFKit
- EPUB reading via local extraction
- Hideable left local library: add multiple PDF/EPUB files and reopen them from the app
- Book-style page navigation with page count and Prev/Next controls
- Reading modes: paginated Page mode and vertical Scroll mode
- Reader fullscreen mode: hide Library/AI and let PDF/EPUB fill the window
- EPUB typography controls: font size and line spacing
- Apple Books companion mode: open a local book in Books, keep ReadAI as a floating AI pane
- GPT-style back-and-forth chat with book excerpt and conversation history
- Select text in the reader and click `询问AI` to summarize it
- AI quick actions: `总结本章` and `总结本段`
- OpenAI API key saved locally

## Run

```sh
bash scripts/build_app.sh
open .build/ReadAI.app
```

## E2E

```sh
bash scripts/e2e_books.sh
```

Core parsing can also be checked separately:

```sh
bash scripts/e2e_book_core.sh
```
