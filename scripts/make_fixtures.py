#!/usr/bin/env python3
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED, ZIP_STORED


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "Tests" / "Fixtures"


def pdf_object(number: int, body: str) -> bytes:
    return f"{number} 0 obj\n{body}\nendobj\n".encode("latin-1")


def write_pdf(path: Path) -> None:
    content1 = "BT /F1 24 Tf 72 720 Td (ReadAI PDF E2E Sample) Tj 0 -36 Td (This page verifies PDF loading.) Tj ET"
    content2 = "BT /F1 24 Tf 72 720 Td (ReadAI PDF E2E Page Two) Tj 0 -36 Td (This page verifies page turning.) Tj ET"
    objects = [
        pdf_object(1, "<< /Type /Catalog /Pages 2 0 R >>"),
        pdf_object(2, "<< /Type /Pages /Kids [3 0 R 6 0 R] /Count 2 >>"),
        pdf_object(3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>"),
        pdf_object(4, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
        pdf_object(5, f"<< /Length {len(content1.encode('latin-1'))} >>\nstream\n{content1}\nendstream"),
        pdf_object(6, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 7 0 R >>"),
        pdf_object(7, f"<< /Length {len(content2.encode('latin-1'))} >>\nstream\n{content2}\nendstream"),
    ]

    data = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for obj in objects:
        offsets.append(len(data))
        data.extend(obj)

    xref_offset = len(data)
    data.extend(f"xref\n0 {len(objects) + 1}\n".encode("latin-1"))
    data.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        data.extend(f"{offset:010d} 00000 n \n".encode("latin-1"))
    data.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n".encode("latin-1")
    )
    path.write_bytes(data)


def write_epub(path: Path) -> None:
    container = """<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""
    opf = """<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" unique-identifier="bookid" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">readai-epub-e2e</dc:identifier>
    <dc:title>ReadAI EPUB E2E Sample</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
  </spine>
</package>
"""
    repeated = " ".join(
        f"This paragraph verifies EPUB page turning segment {i}."
        for i in range(1, 90)
    )
    chapter = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter One</title></head>
  <body>
    <h1>ReadAI EPUB E2E Sample</h1>
    <p>This chapter verifies EPUB loading, text extraction, and page turning.</p>
    <p>{repeated}</p>
  </body>
</html>
"""
    with ZipFile(path, "w") as zf:
        zf.writestr("mimetype", "application/epub+zip", compress_type=ZIP_STORED)
        zf.writestr("META-INF/container.xml", container, compress_type=ZIP_DEFLATED)
        zf.writestr("OEBPS/content.opf", opf, compress_type=ZIP_DEFLATED)
        zf.writestr("OEBPS/chapter1.xhtml", chapter, compress_type=ZIP_DEFLATED)


def main() -> None:
    FIXTURES.mkdir(parents=True, exist_ok=True)
    write_pdf(FIXTURES / "readai-e2e.pdf")
    write_epub(FIXTURES / "readai-e2e.epub")
    print(FIXTURES)


if __name__ == "__main__":
    main()
