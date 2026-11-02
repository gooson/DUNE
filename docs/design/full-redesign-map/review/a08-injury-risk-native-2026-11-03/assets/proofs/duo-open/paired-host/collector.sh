#!/bin/bash
set -euo pipefail
[[ $# -eq 5 ]] || exit 64
screen="$1"
pose="$2"
revision="$3"
device="$4"
selector="$5"
[[ "$screen" =~ ^[a-z][0-9][0-9]$ ]] || exit 64
[[ "$selector" =~ ^DUNEUITests/[A-Za-z0-9_]+/[A-Za-z0-9_]+$ ]] || exit 64
case "$pose" in
  closed) target=0 ;;
  open) target=180 ;;
  *) exit 64 ;;
esac
[[ "$(git rev-parse --short=8 HEAD)" == "$revision" ]] || exit 2
output=".codex-checks/${screen}/duo-${pose}-${revision}"
[[ ! -f "$output/checkpoints.jsonl" ]] || exit 2
mkdir -p "$output"
name=$(python3 -B - "$device" <<'OWN'
import json,sys
from pathlib import Path
root=Path.cwd();rows=json.loads((root/'.codex-checks/worktree-simulators.json').read_text())
r=next(x for x in rows if x['udid']==sys.argv[1]);assert r['worktree']==str(root) and r['preclone_verified'] is True;assert r['name'].startswith('iPhone Duo-wt-');print(r['name'])
OWN
)
python3 -B scripts/lib/worktree-simulator-registry.py is-recorded "$PWD" "$device" "$name"
ROOT_DIR="$PWD"
export ROOT_DIR
source scripts/lib/simulator-boot.sh
wait_for_simulator_boot "$device" "$screen Duo"

/private/tmp/detail-hinge-pinned/hinge-owned -d "$device" "$target" >"$output/set.log" 2>&1
python3 -B -c 'import time; time.sleep(0.5)'
/private/tmp/detail-hinge-pinned/hinge-owned -d "$device" get >"$output/angle-before.txt"
python3 -B scripts/lib/command-deadline.py --seconds 25 -- xcrun devicectl device info displays --device "$device" --timeout 20 --quiet --json-output - >"$output/displays-before.json"
python3 -B - "$output" "$target" before <<'PY'
from pathlib import Path
import json,sys
p,target,suffix=Path(sys.argv[1]),float(sys.argv[2]),sys.argv[3]
assert abs(float((p/f'angle-{suffix}.txt').read_text())-target)<=1
rows=json.loads((p/f'displays-{suffix}.json').read_text())['result']['displays']
active='LCD' if target==0 else 'LCD-1'
assert {d['name'] for d in rows}=={'LCD','LCD-1'}
assert all(d['active']==(d['name']==active) for d in rows)
PY
python3 -B scripts/duo-visual-audit.py "$output" "$device" all scripts/test-ui.sh --no-regen --stream-log --test-plan DUNEUITests-DuoAudit --simulator-udid "$device" --only-testing "$selector" --log-file ".xcodebuild/${screen}-duo-${pose}-${revision}.log"
/private/tmp/detail-hinge-pinned/hinge-owned -d "$device" get >"$output/angle-after.txt"
python3 -B scripts/lib/command-deadline.py --seconds 25 -- xcrun devicectl device info displays --device "$device" --timeout 20 --quiet --json-output - >"$output/displays-after.json"
python3 -B - "$output" "$target" "$revision" <<'PY'
from pathlib import Path
import hashlib,json,sys,time
p,target,revision=Path(sys.argv[1]),float(sys.argv[2]),sys.argv[3]
for suffix in ['before','after']:
    assert abs(float((p/f'angle-{suffix}.txt').read_text())-target)<=1
    rows=json.loads((p/f'displays-{suffix}.json').read_text())['result']['displays']
    active='LCD' if target==0 else 'LCD-1'
    assert {d['name'] for d in rows}=={'LCD','LCD-1'}
    assert all(d['active']==(d['name']==active) for d in rows)
script=Path('/private/tmp/detail-capture-duo.sh')
(p/'pose-proof.json').write_text(json.dumps({'revision':revision,'target':target,'angle_before':float((p/'angle-before.txt').read_text()),'angle_after':float((p/'angle-after.txt').read_text()),'active_display':active,'script_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),'captured_at':time.time(),'native_visual_review':'pending-parent'},indent=2)+'\n')
print('Verified actual angle and active display before/after; inspect new native PNG and AX')
PY
