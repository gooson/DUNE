"""Response transformation preserves document content and security boundaries."""
import importlib.util
import io
import tempfile
import unittest
from html import escape
from html.parser import HTMLParser
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('dashboard_server', ROOT / 'scripts/serve-docs-dashboard.py')
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)
STYLES = (SERVER.ASSETS / 'design-system.css').read_text() + '\n' + (SERVER.ASSETS / 'reader-content.css').read_text()
BRIDGE = (SERVER.ASSETS / 'standalone-system.js').read_text()


class Document(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.security = []
        self.media = []
        self.embedded = []
        self.systems = 0
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'meta' and attrs.get('http-equiv', '').lower() == 'content-security-policy':
            self.security.append(('csp', attrs.get('content')))
        if tag == 'iframe':
            self.security.append(('sandbox', attrs.get('sandbox')))
            if 'data-srcdoc' in attrs:
                self.embedded.append(attrs['data-srcdoc'])
        if tag in ('img', 'video', 'source'):
            self.media.append((tag, attrs.get('src'), attrs.get('srcset'), attrs.get('alt')))
        if tag == 'style' and 'data-dune-served' in attrs:
            self.systems += 1


def render(source, path='docs/design/theme-map/themes/example.html'):
    return SERVER.decorate(source, path, 'http://127.0.0.1:8765', STYLES, BRIDGE)


class DashboardResponseTests(unittest.TestCase):
    def compare(self, original, result):
        before, after = Document(original), Document(result)
        self.assertEqual(before.security, after.security)
        self.assertEqual(before.media, after.media)
        self.assertEqual(after.systems, 1)
        self.assertEqual(len(before.embedded), len(after.embedded))
        for old, new in zip(before.embedded, after.embedded):
            self.compare(old, new)

    def test_nested_opaque_document_keeps_sandbox_csp_and_unicode(self):
        inner = ('<html><head><meta http-equiv="Content-Security-Policy" '
                 'content="script-src \'unsafe-inline\'; style-src \'unsafe-inline\'"></head>'
                 '<body><div class="phone">운동 · 오늘</div><img src="./실제 화면.png" alt="실제 화면"></body></html>')
        source = ('<html><head></head><body><iframe sandbox="allow-scripts" data-srcdoc = "'
                  + escape(inner, quote=True) + '"></iframe></body></html>')
        result = render(source)
        self.compare(source, result)
        embedded = Document(result).embedded[0]
        self.assertIn('<div class="phone">운동 · 오늘</div>', embedded)
        self.assertNotIn('__DUNE_DOCUMENT_CONFIG__', embedded)
        self.assertEqual(result, render(result))

    def test_fragment_is_preserved(self):
        source = '<section class="da-phone"><img src="capture.png" alt="검증 화면"></section>'
        result = render(source)
        self.assertTrue(result.endswith(source))
        self.compare(source, result)

    def test_root_without_styles_can_receive_already_decorated_child(self):
        child = render('<html><head></head><body>시안</body></html>')
        source = '<head></head><iframe sandbox="allow-scripts" data-srcdoc="' + escape(child, quote=True) + '"></iframe>'
        result = render(source)
        self.assertEqual(Document(result).systems, 1)
        self.assertEqual(Document(result).embedded[0], child)

    def test_repository_html_preserves_security_and_capture_references(self):
        files = sorted((ROOT / 'docs/design').rglob('*.html'))
        self.assertTrue(files)
        for path in files:
            with self.subTest(path=path.relative_to(ROOT)):
                source = path.read_text()
                self.compare(source, render(source, path.relative_to(ROOT).as_posix()))


class MemoryConnection:
    def __init__(self, request):
        self.request = io.BytesIO(request)
        self.response = bytearray()

    def makefile(self, mode, buffering):
        return self.request

    def sendall(self, data):
        self.response.extend(data)


class DashboardAccessTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve() / 'repository'
        self.root.mkdir()
        (self.root / 'index.html').write_text('public portal')
        (self.root / 'README.md').write_text('public document')
        (self.root / '.env').write_text('private fixture')
        (self.root / 'docs').mkdir()
        (self.root / 'docs/index.html').write_text('public index')
        (self.root / 'docs/empty').mkdir()
        self.outside = self.root.parent / 'outside.md'
        self.outside.write_text('outside fixture')

    def request(self, path, host='127.0.0.1:8765', method='GET'):
        request = f'{method} {path} HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n'.encode()
        connection = MemoryConnection(request)
        with patch.object(SERVER, 'ROOT', self.root), patch.object(SERVER.Handler, 'log_message'):
            SERVER.Handler(connection, ('127.0.0.1', 12345), SimpleNamespace(server_port=8765))
        response = bytes(connection.response)
        return int(response.split(b' ', 2)[1]), response

    def test_public_documents_and_directory_index_remain_readable(self):
        for path, content in [('/', b'public portal'), ('/README.md', b'public document'), ('/docs/', b'public index')]:
            with self.subTest(path=path):
                status, response = self.request(path)
                self.assertEqual(status, 200)
                self.assertIn(b'Cache-Control: no-store', response)
                self.assertTrue(response.endswith(content))
        status, response = self.request('/README.md', method='HEAD')
        self.assertEqual(status, 200)
        self.assertNotIn(b'public document', response)

    def test_hidden_and_traversal_paths_are_denied(self):
        for path in ['/.env', '/%2eenv', '/.git/config', '/docs/../README.md', '/docs/%2e%2e/README.md', '/bad%00.md']:
            with self.subTest(path=path):
                self.assertEqual(self.request(path)[0], 403)

    def test_symlinks_cannot_expose_external_or_hidden_files(self):
        (self.root / 'external.md').symlink_to(self.outside)
        (self.root / 'hidden.md').symlink_to(self.root / '.env')
        (self.root / 'docs/empty/index.html').symlink_to(self.outside)
        for path in ['/external.md', '/hidden.md', '/docs/empty/']:
            with self.subTest(path=path):
                self.assertEqual(self.request(path)[0], 403)

    def test_directory_listing_is_denied(self):
        self.assertEqual(self.request('/docs/empty/')[0], 403)

    def test_only_loopback_host_headers_are_accepted(self):
        self.assertEqual(self.request('/README.md', host='localhost:8765')[0], 200)
        for host in ['example.com:8765', '127.0.0.1.example.com:8765', 'localhost:9999']:
            with self.subTest(host=host):
                self.assertEqual(self.request('/README.md', host=host)[0], 403)

    def test_missing_public_file_returns_not_found(self):
        self.assertEqual(self.request('/missing.md')[0], 404)


if __name__ == '__main__':
    unittest.main()
