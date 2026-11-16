"""Declare preview assets statically and preload the existing embedded color-lab PNGs.

Codex HTML preview can relocate a document, so dynamically constructed relative
image URLs must not be the only way to locate its assets. Reuse the existing
base64 export sources; do not create another copy of the original PNGs.
"""
from pathlib import Path
import html, json, re
root = Path(__file__).resolve().parent
assets = root.parent
page = assets.parent.parent / 'dune-icon-development.html'
data = json.loads((assets / 'data.js').read_text().removeprefix('window.duneIconData = ').strip().rstrip(';'))
paths = ['original.png'] + [c['image'] for c in data['concepts']]
paths += [r['local_image'] for r in data['references']]
paths += [r['local_image'] for r in data.get('designReferences', []) if r.get('local_image')]
paths = list(dict.fromkeys(paths))
for path in paths:
    assert (assets / path).is_file(), path
bank = '<!-- BEGIN STATIC PREVIEW IMAGE BANK -->\n<div id="dune-image-bank" hidden aria-hidden="true">\n'
bank += '\n'.join(f'<img data-image="{html.escape(path, quote=True)}" src="assets/dune-icon-development/{html.escape(path, quote=True)}" loading="lazy" alt="">' for path in paths)
bank += '\n</div>\n<!-- END STATIC PREVIEW IMAGE BANK -->'
preload = '<!-- BEGIN EMBEDDED LAB SOURCE PRELOADS -->\n'
for c in data['concepts']:
    if c['version'] == 'v6':
        script = f'color-lab/export-sources/{c["id"]}.js'
        assert (assets / script).is_file(), script
        preload += f'<script src="assets/dune-icon-development/{script}"></script>\n'
preload += '<!-- END EMBEDDED LAB SOURCE PRELOADS -->'
text = page.read_text()
if '<!-- BEGIN STATIC PREVIEW IMAGE BANK -->' in text:
    text = re.sub(r'<!-- BEGIN STATIC PREVIEW IMAGE BANK -->.*?<!-- END STATIC PREVIEW IMAGE BANK -->', lambda _: bank, text, flags=re.S)
else:
    text = text.replace('<main class="shell">', bank + '\n<main class="shell">', 1)
if '<!-- BEGIN EMBEDDED LAB SOURCE PRELOADS -->' in text:
    text = re.sub(r'<!-- BEGIN EMBEDDED LAB SOURCE PRELOADS -->.*?<!-- END EMBEDDED LAB SOURCE PRELOADS -->', lambda _: preload, text, flags=re.S)
else:
    text = text.replace('<script src="assets/dune-icon-development/data.js"></script>', preload + '\n<script src="assets/dune-icon-development/data.js"></script>', 1)
page.write_text(text)
print(f'{len(paths)} static image references; 9 shared embedded PNG preloads; no duplicate image files')
