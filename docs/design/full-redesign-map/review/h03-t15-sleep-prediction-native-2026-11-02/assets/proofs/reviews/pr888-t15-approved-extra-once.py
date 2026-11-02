import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

ROOT = Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health')
PUBLIC = Path('/Users/shanks/.codex/worktrees/detail-redesign-h03/Health')
REV = '02cc8c81827fa850c0ff9548c8d746ee6c00fa25'
UID = '32445145-0527-492A-88DA-BEE75911299E'
SELECTOR = 'DUNEUITests/NotificationRoutingRegressionTests/testBedtimeReminderPushesFromNotificationHub'
ORIGINAL_ID = 'pr888-duo-closed-loaded-routes'
PROXY_ID = 'pr888-closed-T15-user-approved-extra-once'
CASE_KEY = ORIGINAL_ID + '::' + SELECTOR
assert Path.cwd().resolve() == ROOT

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()

def method(root):
    source = (root / 'DUNEUITests/Full/NotificationRoutingRegressionTests.swift').read_text()
    start = re.search(r'^    func testBedtimeReminderPushesFromNotificationHub\(', source, re.M)
    assert start
    end = re.search(r'^    }$', source[start.start():], re.M)
    assert end
    return source[start.start():start.start() + end.end()]

assert git(ROOT, 'rev-parse', 'HEAD') == REV and not git(ROOT, 'status', '--porcelain')
assert git(PUBLIC, 'rev-parse', 'HEAD') == 'cfa0d2b7b33c976760f9f71130719f2f659a66fc'
assert not git(PUBLIC, 'status', '--porcelain')
# Compiled validation closure and matching public full files; no partial test-file equivalence.
CLOSURE = {'DUNE/App/TestDataSeeder.swift': 'aeec211b427297c1fcca5e2573515182076e38570bdbdf9e3048de14885e76bb', 'DUNE/App/ContentView.swift': '1f99acd7c7ae1f91f300d3f82de18f255ecb7061ebe9143cd7c1bffe76229cc0', 'DUNE/Presentation/Wellness/SleepPredictionDetail/SleepPredictionDetailView.swift': '5d128c792c95689521e1904c1f63d0e72ea2778a2097eb8b4148cedc2182dc77', 'DUNE/Domain/Models/SleepQualityPrediction.swift': 'c5fa2db319076f9cf6255582416498c91a914ef3c2934274096cdb19523ab2f3', 'DUNE/Domain/UseCases/PredictSleepQualityUseCase.swift': 'a267a9c6606a4de5ac5e6f969d5825ee54a77edf0e3d7332db05e3d62e2e3ffb', 'DUNEUITests/Helpers/UITestBaseCase.swift': '1299e3efbe08b78ebcda033b0abf0b31d1d9635b2822e45a04b5df840b3f7f1e', 'DUNEUITests/Helpers/UITestHelpers.swift': '1543b51342c33b2d607f910fe4f43cbf382d578c9331623b911f96603b2cef6c', 'DUNEUITests/Full/NotificationRoutingRegressionTests.swift': '9b8b72ab3c7c731d0824544e254ff656379d9d55207253606174a624d44a9f21', 'DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift': 'fa2d2fd92db760988479f31e050973d6ecd7b4487420c7d3057a7f409a38cf37'}
for relative, expected in CLOSURE.items():
    assert sha(ROOT / relative) == expected and sha(PUBLIC / relative) == expected
assert method(ROOT) == method(PUBLIC)
for relative in ['DUNE/App/ContentView.swift', 'DUNE/Presentation/Wellness/SleepPredictionDetail/SleepPredictionDetailView.swift']:
    assert sha(ROOT / relative) == sha(PUBLIC / relative)
registry = json.loads((ROOT / '.codex-checks/worktree-simulators.json').read_text())
assert len(registry) == 1 and registry[0]['udid'] == UID
assert registry[0]['worktree'] == str(ROOT) and registry[0]['preclone_verified'] is True
record = ROOT / '.codex-checks/pipeline/check-43fbc7386f6ce0d04ad274fa.json'
history = json.loads(record.read_text())
assert history['id'] == ORIGINAL_ID and len(history['attempts']) == 2
assert all(a['status'] == 'failed' for a in history['attempts'])
original_hash = sha(record)
assert original_hash == '4a0e59f1fa67cacfeb77ea000fd207adc042090c75834b1a7218b8a831d6ea4e'
for name, expected in [('duo-closed-routes-failed-59fdf60f', (2, 1, 1)), ('duo-closed-T15-reveal-failed-0e6cb013', (1, 0, 1))]:
    result = json.loads((ROOT / '.codex-checks/h03/evidence' / name / 'result.json').read_text())
    counts = result['counts']
    assert result['status'] == 'failed' and (counts['executed'], counts['passed'], counts['failed']) == expected
compile_log = ROOT / '.codex-checks/h03/compile-02cc8c81.log'
assert sha(compile_log) == '33548f2195b047a0f0e6ed90acd93d6acc360a924e238cb4263130bd50da23e5'
assert '** TEST BUILD SUCCEEDED **' in compile_log.read_text()
review = Path('/private/tmp/pr888-t15-loaded-leaf-review.md')
assert sha(review) == '57bf9927f36c82a1f4fcf3a1501564405268915c900756aa1fdf6595011e6c3a'
assert review.read_text().startswith('CLEAR')
collector = Path('/private/tmp/pr888-capture-duo-leaves.sh')
assert sha(collector) == '66f5b270c9b6910403d4f35ecd2c5f1febb5745e70a9a70093470d1397981e93'
assert REV in collector.read_text()
folder = ROOT / '.codex-checks/h03/closed-T15-approved-extra-02cc8c81'
folder.mkdir(parents=True, exist_ok=True)
marker = folder / 'approved-extra-consumed-once.json'
assert not marker.exists(), 'This logical check extra is already consumed'
ledger_path = Path('/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/detail-rollout/user-approval-ledger.json')
proof = dict(authorization='모두 1회 추가 허용 알아서 처리하고 머지까지 완료', approvalGroup='2026-11-02-pending-extra-once',
             originalPipelineID=ORIGINAL_ID, selector=SELECTOR, originalRecord=str(record), originalRecordSHA256=original_hash,
             proxyRecordID=PROXY_ID, proxyMeaning='Records only the explicitly approved extra; original two failures remain unchanged',
             approvedExtra=1, consumed=1, remaining=0, revision=REV, publicSource=git(PUBLIC, 'rev-parse', 'HEAD'), device=UID,
             cause='First virtualized row resolved on second run; computed score loaded but duplicate-root-ID assumption failed. Reviewed assertion uses mandatory actual score/guide/confidence leaves; wrapper/Today/capture/Back/hub checks remain',
             reviewSHA256=sha(review), collectorSHA256=sha(collector), compileSHA256=sha(compile_log),
             started=time.time(), status='running')
with ledger_path.with_name('user-approval-ledger.lock').open('a+b') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    ledger = json.loads(ledger_path.read_text())
    old = json.loads(json.dumps(ledger))
    group = ledger['2026-11-02-pending-extra-once']
    assert group['defaultPerPendingLogicalCase']['approvedExtra'] == 1
    assert CASE_KEY not in group.get('consumedLogicalCases', {})
    assert 'H03ClosedT15LoadedLeaves' not in group['perCase']
    group['perCase']['H03ClosedT15LoadedLeaves'] = dict(approvedExtra=1, consumed=1, remaining=0, marker=str(marker), selector=SELECTOR)
    group.setdefault('consumedLogicalCases', {})[CASE_KEY] = str(marker)
    assert all(ledger[k] == v for k, v in old.items() if k != '2026-11-02-pending-extra-once')
    old_group = old['2026-11-02-pending-extra-once']
    assert all(group[k] == value for k, value in old_group.items() if k not in ('perCase', 'consumedLogicalCases'))
    assert all(group['perCase'][k] == v for k, v in old_group['perCase'].items())
    assert all(group['consumedLogicalCases'][k] == v for k, v in old_group.get('consumedLogicalCases', {}).items())
    temporary = ledger_path.with_name(ledger_path.name + '.' + uuid.uuid4().hex + '.tmp')
    temporary.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n')
    os.replace(temporary, ledger_path)
    # Ledger is authoritative: any exception from here consumes the slot without dispatch or refund.
    # Exclusive marker is also mandatory before dispatch; a stale marker blocks re-entry.
    with marker.open('x') as stream:
        json.dump(proof, stream, ensure_ascii=False, indent=2)
        stream.flush()
        os.fsync(stream.fileno())

command = [sys.executable, '-B', 'scripts/codex-pipeline.py', 'run', PROXY_ID,
           '--context', 'H03-T15-02cc8c81-user-approved-extra1-consumed1-remaining0',
           '--scope', 'One original defaultT15 closed case after reviewed loaded-leaf assertion fix; original2failed retained; no H03 rerun/no automatic extra retry',
           '--timeout', '1250', '--', sys.executable, '-B', 'scripts/lib/simulator-test-lock.py', str(ROOT), '--',
           'bash', str(collector), 'h03', 'closed', REV[:8], UID, 'closed-retry']
environment = dict(os.environ, DUNE_SIM_TEST_LOCK_SCOPE='worktree', DUNE_SIM_TEST_LOCK_WAIT_SECONDS='0', DUNE_UI_TEST_WALL_TIMEOUT='1200')
try:
    result = subprocess.run(command, env=environment, timeout=1280)
    proof['exitCode'] = result.returncode
    proof['status'] = 'passed' if result.returncode == 0 else 'failed'
except BaseException as exc:
    proof['status'] = 'failed'
    proof['error'] = repr(exc)
finally:
    proof['originalHistoryUnchanged'] = sha(record) == original_hash
    proof['sourceUnchanged'] = git(ROOT, 'rev-parse', 'HEAD') == REV and not git(ROOT, 'status', '--porcelain')
    proof['completed'] = time.time()
    marker.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
assert proof['originalHistoryUnchanged'] and proof['sourceUnchanged']
print(json.dumps(proof, ensure_ascii=False))
sys.exit(0 if proof['status'] == 'passed' else 1)
