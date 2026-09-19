#!/usr/bin/env python3
"""Check Watch runnable normalization without modifying the workspace project."""
import re
import subprocess
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as directory:
    for name in ('DUNEWatch', 'DUNEWatchTests', 'DUNEWatchUITests', 'DUNE'):
        source = root / 'DUNE/DUNE.xcodeproj/xcshareddata/xcschemes' / f'{name}.xcscheme'
        path = Path(directory) / source.name
        # Retain the real generator formatting and simulate its added attribute.
        text = source.read_text()
        def generated(match):
            block = match.group(0)
            if 'BuildableName = "DUNEWatch.app"' in block and 'BlueprintName' not in block:
                block = block.replace('BuildableName = "DUNEWatch.app"', 'BuildableName = "DUNEWatch.app"\n            BlueprintName = "DUNEWatch"')
            return block
        text = re.sub(r'<BuildableProductRunnable\b.*?</BuildableProductRunnable>', generated, text, flags=re.S)
        path.write_text(text)
        before = ET.fromstring(text)
        command = ['bash', '-c', 'source "$1"; normalize_xcscheme "$2"', 'test', str(root / 'scripts/lib/regen-project.sh'), str(path)]
        subprocess.run(command, check=True)
        first = path.read_bytes()
        filtered = subprocess.run(
            ['bash', str(root / 'scripts/lib/xcscheme-clean-filter.sh')],
            input=text.encode(), capture_output=True, check=True,
        ).stdout
        assert filtered == first, f'{name}: clean filter differs from generator' 
        subprocess.run(command, check=True)
        assert path.read_bytes() == first, f'{name}: not idempotent'
        after = ET.fromstring(first)
        for ref in after.findall('.//BuildableProductRunnable/BuildableReference'):
            if ref.get('BuildableName') == 'DUNEWatch.app':
                assert 'BlueprintName' not in ref.attrib
        for selector in ('.//BuildActionEntry/BuildableReference', './/MacroExpansion/BuildableReference', './/TestableReference/BuildableReference'):
            assert [r.attrib for r in before.findall(selector)] == [r.attrib for r in after.findall(selector)], name
        if name == 'DUNE':
            assert [r.attrib for r in before.findall('.//BuildableProductRunnable/BuildableReference')] == [r.attrib for r in after.findall('.//BuildableProductRunnable/BuildableReference')]
print('Passed: 3 Watch schemes, iOS preservation, and repeated normalization.')
