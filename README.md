# ReadAI

Native macOS reading app with a hideable left library, center reading pane, and right AI chat pane.

## Features

- PDF reading via PDFKit
- EPUB reading via local extraction
- Hideable left local library: add multiple PDF/EPUB files and reopen them from the app
- Contents sidebar for EPUB chapter navigation
- Book-style page navigation with page count and Prev/Next controls
- Progress slider for jumping across pages
- In-book search with result jumps
- Bookmarks, highlights, and notes
- Per-book reading progress restore, including the last opened book
- Keyboard page turning with arrow keys and Space
- Reading modes: paginated Page mode and vertical Scroll mode
- Reader themes: dark, light, and sepia
- Compact Books-style reader toolbar with typography controls inside `Settings`
- Reader fullscreen mode: hide Library/AI and let PDF/EPUB fill the window
- EPUB typography controls: font size and line spacing
- Book-like EPUB layout with narrower measure, title/subtitle styling, and wider margins
- Apple Books companion mode: open a local book in Books, keep ReadAI as a floating AI pane
- GPT-style back-and-forth chat with book excerpt and conversation history
- Select text in the reader and click `询问AI` to summarize it
- AI quick actions: `总结本章` and `总结本段`
- OpenAI API key saved locally

## Run

```sh
bash scripts/build_app.sh
open .app-build/ReadAI.app
```

## E2E

```sh
bash scripts/test_all.sh
```

The same full suite runs in GitHub Actions on every push and pull request.

Enable the local pre-commit gate:

```sh
git config core.hooksPath .githooks
```

Individual checks:

```sh
bash scripts/e2e_book_core.sh
bash scripts/e2e_books.sh
bash scripts/e2e_features.sh
bash scripts/e2e_progress.sh
```
