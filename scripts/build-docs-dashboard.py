#!/usr/bin/env python3
"""Build the offline HTML dashboard from every repository HTML document."""

import argparse
import html
import json
import re
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "index.html"
TEMPLATE = ROOT / "docs/dashboard/template.html.in"
SYSTEM = ROOT / "docs/dashboard/design-system.json"
HUBS = {
    "docs/design/theme-map/index.html",
    "docs/design/layout-map/index.html",
    "docs/design/full-redesign-map/index.html",
    "docs/design/phone-design-map/actual/index.html",
}
GROUPS = ("기준 맵", "디자인 시안", "실제 화면", "레이아웃", "편집 원본", "기타")


def design_outputs():
    system = json.loads(SYSTEM.read_text())
    sections = ["/* Generated from design-system.json. Shared by the portal and every document. */"]
    for mode, values in system["themes"].items():
        declarations = "\n".join(f"  --dune-{key}: {value};" for key, value in values.items())
        selector = ':root, :root[data-theme="light"]' if mode == "light" else ':root[data-theme="dark"]'
        sections.append(f'{selector} {{\n  color-scheme: {mode};\n{declarations}\n}}')
    declarations = "\n".join(f"  --dune-{key}: {value};" for key, value in system["tokens"].items())
    sections.append(":root {\n" + declarations + "\n  --dune-surface: linear-gradient(145deg, var(--dune-glass-start), var(--dune-glass-end));\n  --dune-chrome: linear-gradient(145deg, var(--dune-chrome-start), var(--dune-chrome-end));\n  --dune-shadow: 0 12px 36px var(--dune-shadow-color), inset 0 1px 0 var(--dune-highlight);\n}")
    outputs = {ROOT / "docs/dashboard/design-system.css": "\n\n".join(sections) + "\n"}
    for mode, palette in system["themes"].items():
        outputs[ROOT / f"docs/dashboard/dune-scene-{mode}.svg"] = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 1000" preserveAspectRatio="xMidYMid slice"><defs><radialGradient id="light"><stop stop-color="{palette['backdrop-glow']}" stop-opacity=".7"/><stop offset="1" stop-color="{palette['backdrop-glow']}" stop-opacity="0"/></radialGradient><filter id="soft"><feGaussianBlur stdDeviation="18"/></filter></defs><path fill="{palette['backdrop-sky']}" d="M0 0h1600v1000H0z"/><ellipse cx="1190" cy="270" rx="700" ry="520" fill="url(#light)"/><g filter="url(#soft)"><path fill="{palette['backdrop-far']}" d="M-80 590C400 250 800 920 1700 350v800H-80Z"/><path fill="{palette['backdrop-middle']}" d="M-80 940C450 360 850 680 1700 560v600H-80Z"/><path fill="{palette['backdrop-near']}" d="M-80 880C400 690 700 1160 1700 770v400H-80Z"/></g></svg>\n'''
    return outputs


class TitleParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_title = False
        self.parts = []
        self.links = []
        self.redirect = ""

    def handle_starttag(self, tag, attrs):
        if tag == "title":
            self.in_title = True
        if tag == "a":
            href = dict(attrs).get("href")
            if href:
                self.links.append(href)
        if tag == "meta":
            attributes = dict(attrs)
            if attributes.get("http-equiv", "").lower() == "refresh":
                match = re.search(r"url\s*=\s*['\"]?([^'\"]+)", attributes.get("content", ""), re.I)
                if match:
                    self.redirect = match[1].strip()

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.parts.append(data)


def category(path):
    if path in HUBS:
        return "기준 맵"
    if path.endswith("-fragment.html"):
        return "편집 원본"
    if "/review/" in path or "/actual/" in path:
        return "실제 화면"
    if "/theme-map/" in path:
        return "디자인 시안"
    if "/layout-map/" in path:
        return "레이아웃"
    return "기타"


def topic(path):
    if "siri" in path:
        return "Siri · 건강 조회"
    if "live-activity" in path or "widget" in path:
        return "Widget · Live Activity"
    if "watch" in path:
        return "Watch"
    if "today" in path or "daily-summary" in path or "digest" in path or "condition-detail" in path or "hrv-rhr" in path or "stress" in path:
        return "Today · 컨디션"
    if "activity" in path or "cardio" in path or "workout" in path or "running" in path:
        return "Activity · 운동"
    if "wellness" in path or "sleep" in path:
        return "Wellness · 수면"
    if "life" in path or "habit" in path:
        return "Life · 습관"
    if "/phone-design-map/actual/" in path:
        return "기기별 화면"
    return "공통 · 테마"


def inventory():
    themes = json.loads((ROOT / "docs/design/theme-map/manifest.json").read_text())
    names = {item["file"]: item["name"] + " · " + item["title"] for item in themes["themes"]}
    entries = []
    for file in sorted(ROOT.rglob("*.html")):
        relative = file.relative_to(ROOT)
        if file == OUTPUT or any(part.startswith(".") or part == "node_modules" for part in relative.parts):
            continue
        path = relative.as_posix()
        parser = TitleParser()
        parser.feed(file.read_text(encoding="utf-8"))
        title = " ".join("".join(parser.parts).split())
        title = title or names.get(file.name) or file.stem.replace("-", " ")
        if "/siri-health-queries-" in path:
            device = {"iphone-sdk272": "iPhone", "duo-closed-sdk272": "Duo 접힘", "duo-open-sdk272": "Duo 펼침"}.get(file.parent.name)
            if device:
                title = "Siri 건강 조회 · " + device + " 실제 화면"
        dates = re.findall(r"\d{4}-\d{2}-\d{2}", path)
        links = []
        for href in parser.links:
            parsed = urlsplit(href)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            target = (file.parent / unquote(parsed.path)).resolve()
            if target.is_relative_to(ROOT) and target.is_file():
                links.append(target.relative_to(ROOT).as_posix())
        redirect = ""
        if parser.redirect:
            parsed = urlsplit(parser.redirect)
            target = (file.parent / unquote(parsed.path)).resolve()
            if not parsed.scheme and not parsed.netloc and target.is_relative_to(ROOT) and target.is_file():
                redirect = target.relative_to(ROOT).as_posix()
        profile = "evidence" if category(path) == "실제 화면" else "reference" if path in HUBS else "artifact" if category(path) == "편집 원본" else "study" if category(path) == "디자인 시안" else "layout"
        entries.append({"path": path, "href": quote(path, safe="/"), "title": title, "redirect": redirect, "profile": profile,
                        "group": category(path), "topic": topic(path), "date": max(dates, default=""),
                        "links": sorted(set(links))})
    return sorted(entries, key=lambda item: (GROUPS.index(item["group"]), item["topic"], item["title"], item["path"]))


def render():
    entries = inventory()
    counts = Counter(item["group"] for item in entries)
    rows = []
    for item in entries:
        title, group, path, href, subject, date = (html.escape(item[key], quote=True) for key in ("title", "group", "path", "href", "topic", "date"))
        rows.append(f'''<tr class="doc-row" data-group="{group}" data-topic="{subject}" data-path="{path}" data-date="{date}">
<td class="document-cell"><a class="document-title" href="{href}" target="_blank" rel="noopener">{title}<span aria-hidden="true"> →</span></a><span class="document-path">{path}</span></td>
<td><span class="tag" data-kind="{group}">{group}</span></td><td class="topic-cell">{subject}</td><td class="date-cell">{date or '—'}</td>
<td class="action-cell"><button type="button" class="preview-button" data-preview="{href}" data-title="{title}" aria-label="{title} 문서 보기" hidden>보기</button></td></tr>''')
    options = '<option value="all">전체 분류</option>' + "".join(f'<option value="{group}">{group} ({counts[group]})</option>' for group in GROUPS if counts[group])
    topics = sorted({item["topic"] for item in entries})
    topic_options = '<option value="all">전체 주제</option>' + "".join(f'<option value="{html.escape(subject, quote=True)}">{html.escape(subject)}</option>' for subject in topics)
    recent = sorted((item for item in entries if item["date"] and item["group"] == "실제 화면"), key=lambda item: (item["date"], item["path"]), reverse=True)[:5]
    recent_links = "".join(f'<li><a href="{item["href"]}" target="_blank" rel="noopener"><span>{html.escape(item["title"])}</span><time>{item["date"]}</time></a></li>' for item in recent)
    document_data = json.dumps(entries, ensure_ascii=False).replace("<", "\\u003c")
    shared_styles = design_outputs()[ROOT / "docs/dashboard/design-system.css"] + "\n" + (ROOT / "docs/dashboard/reader-content.css").read_text()
    replacements = {
        "@@ROWS@@": "\n".join(rows),
        "@@GROUP_OPTIONS@@": options,
        "@@TOPIC_OPTIONS@@": topic_options,
        "@@RECENT@@": recent_links,
        "@@DOCUMENT_DATA@@": document_data,
        "@@DESIGN_STYLES@@": json.dumps(shared_styles, ensure_ascii=False).replace("<", "\\u003c"),
        "@@DESIGN_CONFIGURATION@@": SYSTEM.read_text().replace("<", "\\u003c"),
        "@@TOTAL@@": str(len(entries)),
        "@@ACTUAL@@": str(counts["실제 화면"]),
        "@@CONCEPTS@@": str(counts["디자인 시안"]),
        "@@LAYOUTS@@": str(counts["레이아웃"]),
        "@@FRAGMENTS@@": str(counts["편집 원본"]),
        "@@HUBS@@": str(counts["기준 맵"]),
        "@@PROPOSALS@@": str(counts["디자인 시안"] + counts["레이아웃"]),
    }
    result = TEMPLATE.read_text(encoding="utf-8")
    for key, value in replacements.items():
        result = result.replace(key, value)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail when the HTML inventory or template changed")
    args = parser.parse_args()
    result = render()
    outputs = {OUTPUT: result, **design_outputs()}
    if args.check:
        if any(not path.exists() or path.read_text(encoding="utf-8") != content for path, content in outputs.items()):
            parser.exit(1, "Dashboard is out of date. Run python3 scripts/build-docs-dashboard.py\n")
        print(f"Dashboard is current: {len(inventory())} HTML documents")
    else:
        for path, content in outputs.items():
            path.write_text(content, encoding="utf-8")
        print(f"Built {OUTPUT.relative_to(ROOT)}: {len(inventory())} HTML documents")


if __name__ == "__main__":
    main()
