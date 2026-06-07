#!/usr/bin/env python3
import html
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import PurePosixPath
from zipfile import ZipFile


NS = {
    "container": "urn:oasis:names:tc:opendocument:xmlns:container",
    "opf": "http://www.idpf.org/2007/opf",
    "dc": "http://purl.org/dc/elements/1.1/",
}

MAX_CHAPTERS = int(os.environ.get("READAI_EPUB_MAX_CHAPTERS", "0"))
MAX_CHARS = int(os.environ.get("READAI_EPUB_MAX_CHARS", "0"))
MIN_READABLE_CHARS = 300


def text_from_html(raw: bytes) -> str:
    source = raw.decode("utf-8", errors="replace")
    source = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", source)
    source = re.sub(r"(?s)<[^>]+>", " ", source)
    source = html.unescape(source)
    return re.sub(r"\s+", " ", source).strip()


def child_text(node: ET.Element, path: str) -> str:
    child = node.find(path, NS)
    if child is None or child.text is None:
        return ""
    return child.text.strip()


def chapter_payload(index: int, text: str) -> dict:
    if MAX_CHARS > 0:
        body = text[:MAX_CHARS]
        truncated = len(text) > MAX_CHARS
    else:
        body = text
        truncated = False
    return {
        "title": f"Chapter {index}",
        "text": body,
        "truncated": truncated,
    }


def load_epub(path: str) -> dict:
    with ZipFile(path) as epub:
        container = ET.fromstring(epub.read("META-INF/container.xml"))
        rootfile = container.find(".//container:rootfile", NS)
        if rootfile is None:
            raise ValueError("missing OPF rootfile")

        opf_path = rootfile.attrib["full-path"]
        opf_dir = str(PurePosixPath(opf_path).parent)
        if opf_dir == ".":
            opf_dir = ""

        package = ET.fromstring(epub.read(opf_path))
        title = child_text(package, ".//dc:title") or PurePosixPath(path).stem

        manifest = {}
        for item in package.findall(".//opf:manifest/opf:item", NS):
            item_id = item.attrib.get("id")
            href = item.attrib.get("href")
            if item_id and href:
                manifest[item_id] = str(PurePosixPath(opf_dir, href))

        spine = package.findall(".//opf:spine/opf:itemref", NS)
        chapters = []
        fallback = None
        for index, itemref in enumerate(spine, start=1):
            href = manifest.get(itemref.attrib.get("idref", ""))
            if not href:
                continue
            try:
                text = text_from_html(epub.read(href))
            except KeyError:
                continue
            if text:
                chapter = chapter_payload(index, text)
                if fallback is None:
                    fallback = chapter
                if len(text) < MIN_READABLE_CHARS:
                    continue
                chapters.append(chapter)
                if MAX_CHAPTERS > 0 and len(chapters) >= MAX_CHAPTERS:
                    break

        if not chapters and fallback is not None:
            chapters.append(fallback)

        return {
            "title": title,
            "chapterCount": len(spine),
            "chapters": chapters,
        }


def main() -> int:
    args = sys.argv[1:]
    output = None
    if "--output" in args:
      index = args.index("--output")
      output = args[index + 1]
      del args[index:index + 2]

    try:
        data = json.dumps(load_epub(args[0]), ensure_ascii=False)
        if output:
            with open(output, "w", encoding="utf-8") as file:
                file.write(data)
        else:
            print(data)
        return 0
    except Exception as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
