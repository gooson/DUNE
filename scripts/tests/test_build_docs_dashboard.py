"""Structural contracts for generated documentation and source-backed shortcuts."""
import importlib.util
import json
import re
import unittest
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('dashboard_builder', ROOT / 'scripts/build-docs-dashboard.py')
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.tables = []
        self.table = None
        self.row = None
        self.cell = None
        self.script = None
        self.documents = ''
        self.in_palette = False
        self.palette_text = []
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'table':
            self.table = []
        elif tag == 'tr' and self.table is not None:
            self.row = []
        elif tag in ('td', 'th') and self.row is not None:
            self.cell = []
        elif tag == 'br' and self.cell is not None:
            self.cell.append('\n')
        elif tag == 'script':
            self.script = attrs.get('id')
        elif tag == 'dialog' and attrs.get('id') == 'command-palette':
            self.in_palette = True

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)
        if self.script == 'document-data':
            self.documents += data
        if self.in_palette:
            self.palette_text.append(data)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            self.row.append(''.join(self.cell).strip())
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            self.table.append(self.row)
            self.row = None
        elif tag == 'table' and self.table is not None:
            self.tables.append(self.table)
            self.table = None
        elif tag == 'script':
            self.script = None
        elif tag == 'dialog':
            self.in_palette = False


class DashboardBuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.page = Page(BUILDER.render())

    def test_shortcut_rows_are_two_cells_and_cover_registered_phrases(self):
        rows = next(table for table in self.page.tables if table[0] == ['동작', '등록 문구'])
        self.assertEqual(len(rows), 11)
        for row in rows:
            self.assertEqual(len(row), 2, row)
        source = (ROOT / 'DUNE/App/Intents/DUNEShortcuts.swift').read_text()
        phrases = re.findall(r'"([^"\n]*\\\(\.applicationName\)[^"\n]*)"', source)
        self.assertTrue(phrases)
        documented = '\n'.join(row[1] for row in rows[1:])
        for phrase in phrases:
            with self.subTest(phrase=phrase):
                self.assertIn(phrase.replace(r'\(.applicationName)', '{앱 이름}'), documented)

    def test_palette_count_matches_complete_unique_html_inventory(self):
        documents = json.loads(self.page.documents)
        paths = {document['path'] for document in documents}
        self.assertEqual(len(paths), len(documents))
        self.assertEqual(paths, {item['path'] for item in BUILDER.inventory()})
        self.assertIn(f'문서 {len(paths)}개', ''.join(self.page.palette_text))


if __name__ == '__main__':
    unittest.main()
