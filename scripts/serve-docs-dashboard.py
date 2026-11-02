#!/usr/bin/env python3
"""Serve docs with shared DUNE styling while retaining iframe sandbox and CSP."""
import argparse
import html
import io
import json
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'docs/dashboard'
MARKER = '<style id="dune-document-system" data-dune-served>'


def decorate(source, path, origin, styles, bridge, depth=0):
    """Decorate a response and its embedded documents without editing sources."""
    if depth > 5 or MARKER in source:
        return source

    def nested(match):
        content = decorate(html.unescape(match.group(3)), path, origin,
                           styles, bridge, depth + 1)
        return match.group(1) + html.escape(content, quote=True) + match.group(2)

    source = re.sub(r'(\bdata-srcdoc\s*=\s*(["\']))(.*?)\2', nested, source,
                    flags=re.S | re.I)
    if '/review/' in path or '/actual/' in path:
        profile = 'evidence'
    else:
        profile = 'reference' if path.endswith('/index.html') else 'study'
    protection = json.loads((ASSETS / 'design-system.json').read_text())['protection']
    configuration = {
        'selectors': protection['selectors'] + protection['documents'].get(path, []),
        'profile': profile,
        'base': origin + '/' + path,
    }
    config = json.dumps(configuration, ensure_ascii=False).replace('<', '\\u003c')
    bootstrap = (ASSETS / 'document-ux.js').read_text() + '\n' + bridge.replace('__DUNE_DOCUMENT_CONFIG__', config)
    addition = (MARKER + styles.replace('</style', '<\\/style') + '</style><script>'
                + bootstrap.replace('</script', '<\\/script') + '</script>')
    if re.search(r'</head\s*>', source, re.I):
        return re.sub(r'</head\s*>', lambda _: addition + '</head>', source,
                      count=1, flags=re.I)
    return addition + source


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def send_head(self):
        port = self.server.server_port
        host = self.headers.get('Host', f'127.0.0.1:{port}').lower()
        allowed_hosts = {f'127.0.0.1:{port}', f'localhost:{port}'}
        if port == 80:
            allowed_hosts.update(('127.0.0.1', 'localhost'))
        if host not in allowed_hosts:
            self.send_error(403, 'Only loopback hosts are supported')
            return None
        try:
            parts = unquote(urlsplit(self.path).path).split('/')
            path = Path(self.translate_path(self.path)).resolve()
            root = ROOT.resolve()
        except (OSError, RuntimeError, ValueError):
            self.send_error(403, 'Invalid public path')
            return None
        if (any(part.startswith('.') for part in parts if part)
                or not path.is_relative_to(root)
                or any(part.startswith('.') for part in path.relative_to(root).parts)):
            self.send_error(403, 'Path is not public')
            return None
        if path.is_dir():
            path = (path / 'index.html').resolve()
            if (not path.is_relative_to(root) or not path.is_file()
                    or any(part.startswith('.') for part in path.relative_to(root).parts)):
                self.send_error(403, 'Directory listings are disabled')
                return None
        if (path.suffix.lower() != '.html' or not path.is_file()
                or path == ROOT / 'index.html'
                or not path.is_relative_to(ROOT / 'docs/design')):
            return super().send_head()
        styles = ((ASSETS / 'design-system.css').read_text() + '\n'
                  + (ASSETS / 'reader-content.css').read_text())
        bridge = (ASSETS / 'standalone-system.js').read_text()
        content = decorate(
            path.read_text(), path.relative_to(ROOT).as_posix(),
            f'http://{host}', styles, bridge,
        ).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(content)))
        self.end_headers()
        return io.BytesIO(content)

    def log_message(self, format, *args):
        if len(args) > 1 and str(args[1]).startswith(('4', '5')):
            super().log_message(format, *args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'DUNE docs: http://127.0.0.1:{server.server_port}/index.html', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
