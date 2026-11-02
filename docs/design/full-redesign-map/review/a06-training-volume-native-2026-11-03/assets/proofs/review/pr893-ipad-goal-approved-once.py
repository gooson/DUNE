#!/usr/bin/env python3
"""Prepared A06 one-shot guard. Independent review and readiness proof required before execution."""
if not __debug__:
 raise SystemExit('Safety assertions require non-optimized Python')
import fcntl, hashlib, json, os, plistlib, subprocess, sys, time, uuid
from pathlib import Path
ROOT=Path('/Users/shanks/.codex/worktrees/detail-redesign-a06/Health')
REV='e206c0f30b18532c509bc7aa554c3825a6711ba2'
UID='00D70DEA-41CA-46FB-85F6-23F022AD98C9'
NAME='iPad mini (A20 Pro)-wt-Health-detail-redesign-a06-93fc5bbf51df'
SELECTOR='DUNEUITests/ChartInteractionRegressionUITests/testTrainingVolumeGoalContextAndPreviousRangeAcrossPeriods'
ORIGINAL='a06-ui-ipad-core-goals-duration'
GROUP='2026-11-02-pending-extra-once'
PROXY='pr893-ipad-goal-approved-extra-once-e206c0f3'
LEDGER=Path('/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/detail-rollout/user-approval-ledger.json')
MARKER=ROOT/'.codex-checks/a06/ipad-goal-approved-extra-e206c0f3-consumed.json'
INFRA=ROOT/'.codex-checks/a06/ipad-goal-a20-infra-e206c0f3/proof.json'
PINS={'files': {'DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift': '92d7d9303b167161c02456ff7b499ce42861bc5ab73cfa5ebe5da6886f5d36bd', 'DUNE/Domain/Models/TrainingVolume.swift': 'e85f82e3ff6d18d9e9abdf795e381147a208de9f19b655e2e439595812258bcb', 'DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift': 'bbe5234af78cabc32e62f1da17deedb02c3cc02df82d4d287fc4e83e869ad075', 'DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailViewModel.swift': '485d3f95757d9e27128ebce9f125b60a2c4259f2610ecf66a6042e108187a31e', 'DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift': '8a7196995108d5681fe38c0bce1a00c7795f0bec0f09cb2562152945e22694bd', 'DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift': '98035d40210578fbef0b592978d99175bb6f832cafed274a0aaa82804909b35c', 'DUNE/Presentation/Shared/Components/ChangeBadge.swift': 'c738dd68fc609f53f93a0bd6b8067bc9009c4e8ba551e658cee1294319a3a325', 'DUNE/Presentation/Activity/ActivityView.swift': '9f985b8a15aff300eae065162153060d2c5e8e7cba54213035b0bc5d2ba01cc2', 'DUNE/App/ContentView.swift': '1f99acd7c7ae1f91f300d3f82de18f255ecb7061ebe9143cd7c1bffe76229cc0', 'DUNE/App/TestDataSeeder.swift': 'aeec211b427297c1fcca5e2573515182076e38570bdbdf9e3048de14885e76bb', 'DUNEUITests/Full/ActivityExerciseRegressionTests.swift': 'f76ee6f5bb3f5d8573eab14f5902c2ebc37a5090176d314cd03967b8f60d20ed', 'DUNEUITests/Regression/ChartInteractionRegressionUITests.swift': '8b27ea19aaf2df0c0ee3ca668d7f01a6dd7209d1cf38c3f4cfaa44eb29bba435', 'DUNEUITests/Helpers/UITestBaseCase.swift': '1299e3efbe08b78ebcda033b0abf0b31d1d9635b2822e45a04b5df840b3f7f1e', 'DUNEUITests/Helpers/UITestHelpers.swift': '1543b51342c33b2d607f910fe4f43cbf382d578c9331623b911f96603b2cef6c', 'DUNEUITests/DUNEUITests-DesignCapture.xctestplan': '43b6845f3a9ce24fa8c2a9efeb27d569e0ee2cd81a1d87fe7283aeb091588256', 'DUNETests/TrainingVolumeAnalysisServiceTests.swift': '25a75007dbdc7dfce6a086d7569919fac418209a6e447c1f442eef10f846f16c', 'DUNETests/TrainingVolumeViewModelTests.swift': '130c62b792e0eefde639ebbb651ec18421b2e1f90446d8d9959391e1d8685f80', 'DUNETests/ExerciseTypeDetailViewModelTests.swift': 'b07880e2be0f933c8890e84fb6966e373012591c4e37867563a8dd35440497d5', 'scripts/test-ui.sh': '2289203358eebb3bd32522b731623103925c11bfffda65b273e55f0a02a54d59', 'scripts/codex-pipeline.py': '2d12b83aefb64bf03ecb4551faf00dff9be3f71667bf243f33d4390192bda53c', 'scripts/lib/simulator-test-lock.py': 'f1f57a001e1b7414da39b8e7085ee7f4d68c23428848c208e00ea40e81e9a407', 'DUNE/Presentation/Activity/TrainingVolume/Components/ActivityRingView.swift': 'e455cada7dd6ee2675cd18f489685ca6a054dd7476701d4a046601ff8da465d7', 'DUNE/Presentation/Activity/TrainingVolume/Components/ExerciseTypeSummaryRow.swift': 'e9de6a313b501c85912622fd765850fafd28a506d0219b4cef7f36f0bddb596e', 'DUNE/Presentation/Activity/TrainingVolume/Components/PeriodComparisonView.swift': '543e3956648f6a07bbcec5b85d2c33b562e910f6a10f463c680d0ede3cf75aa3', 'DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift': 'a67d65468bfdad2f31c7074309eacce8f01def6d15346d2aa39b2f2fb6f1d91e', 'DUNE/Presentation/Activity/TrainingVolume/Components/TrainingVolumeSummaryCard.swift': 'd5a95161a626c2a8a531f8e1653cbef1820475df80a6fd17d443249ae7a325c1', 'DUNE/Presentation/Activity/TrainingVolume/Components/VolumeDonutChartView.swift': '05b7ab22310360aee4d39710d498bb0dfa3c8f161cc167506fad1b79a90fdb46'}, 'history': {'/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-08e4e37289a3fdd7061d99ed.json': '1a218a885203a94e88ad171393e70a9a91e4124c7c174db6b6012985e5a9a08b', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-08e4e37289a3fdd7061d99ed-b1db08eb0ec04aebaab086621f4dd4e0.log': 'bda0dae7c48b7dbe00875847ddf83c3e57c3b3b9d7c72d7d1642563aa989aab4', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-08e4e37289a3fdd7061d99ed-ee0e249bba7a44a08de9f7d1b58e3303.log': '0bcb022ceeef3c1935c41edc1433ad37e2bd5a55ee88f551b27015b29c30ba4a', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/evidence/ui-ipad-core-conditional-localized-period-failure/result.json': 'e2cd9f77529469df5f76e9d463355e02772a39b7ac8965a7ab598e0e667531f1', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/evidence/ui-ipad-core-conditional-localized-period-failure/summary.json': '47646054e737c70174dd2f27f72c81f852b02f6542a052a7f058d4cea28aa2ea', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/evidence/ui-ipad-core-conditional-localized-period-failure/tests.json': '04795f5770d1605a7a89715e59356c9373cd0ae8ad9dfabc54922c3e1b01ffcb', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/evidence/ui-ipad-core-conditional-localized-period-failure/provenance.json': '0e5b066653800473e9880e4fc9cf0d48ed681f61efa3b8841a857536ce999547', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/evidence/ui-ipad-core-conditional-localized-period-failure/run.log.gz': 'd8b62e5e9de18d7eb32b64de7504e11b68b234954d31fd5c63240df92320a996', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/retry-proof/cause-remediation.json': '4d16517bc7d705d682d3e0356e3a29a497ec0d46105feadb86803eae2d2bf7da'}, 'proofs': {'/private/tmp/pr893-review-architecture.md': '400c7b5967e3f32b1e2a026df815dc88bf4f967855c4015f75a0a22bb3627288', '/private/tmp/pr893-review-data.md': '8b1582249d16f43be73ec2f097fd3462e5ac1fa1fa6a6186c10a2e747d0f0fcb', '/private/tmp/pr893-review-performance.md': 'b7a64862cd3414c1efc64f4f19025987a0c5bc6ae288dca3ced63252b7f69c6e', '/private/tmp/pr893-review-security.md': 'bc207ca3f2667460b82eb52b81d105e8b3b24eaae1c450418e7f19ab07d12d04', '/private/tmp/pr893-review-simplicity.md': '0da21a7557941d845c2d86bddb2023fe7e99cdc3356edb5a46686a6429f16ea7', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/pipeline-receipt.json': 'ab9f1b05567c763cbba5316f59c2576eeaeb500bdf91266f80e453503bfd8feb', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/pipeline-output.log': '39edb3b0c128a6cc35cb2cc0537c36f0eb2e240651f25da7a090e35132aa7a2d', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/summary.json': 'dce6f16dc7c914b50ef93d1dfe7436d31f7e963ff8d824c6822f428a62f52c31', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/tests.json': 'bd4b0b778d04a39a6b200c53adbc8ed8eb975bc7b79e3920780d71def28c2b84', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/provenance.json': 'a37013d4af178a1c1df5dd65192c815cb034ab59a7273bf3a3f42a8d137c950c', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/run.log.gz': '28b49e8ebf029715fe99db7333821e10deb11ea164669a879a73dbc81bce017a'}}
# Parent must add independently verified current normal-run compile receipt and hashes.
COMPILE_PROOF = {'revision': 'e206c0f30b18532c509bc7aa554c3825a6711ba2', 'normal_selector': 'DUNEUITests/ChartInteractionRegressionUITests/testTrainingVolumeSurfaceShowsOverviewChartsAndTypeList', 'result_status': 'passed', 'receipt': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/pipeline/check-bbd74254f3d724970798d467.json', 'result': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.xcodebuild/a06-ipad-normal-e206c0f3.log.result.json', 'pipeline_log': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/pipeline/check-bbd74254f3d724970798d467-9ad3d9672e284752a4dab8c012746adb.log', 'raw_log': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.xcodebuild/a06-ipad-normal-e206c0f3.log', 'tests': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/tests.json', 'provenance': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/provenance.json', 'summary': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/summary.json', 'archived_log': '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/run.log.gz', 'hashes': {'/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/pipeline/check-bbd74254f3d724970798d467.json': '548c73ac440e622f58e8a500128d768f55a20e1f9b38fddca4322773901431cb', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.xcodebuild/a06-ipad-normal-e206c0f3.log.result.json': '5734f6a520ae852fae671fc1a2c40bd0287efacb658dbd533d3dd61557bd182c', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/pipeline/check-bbd74254f3d724970798d467-9ad3d9672e284752a4dab8c012746adb.log': 'a36b16e47f394af902dcbae2dd648ba1c61834491fc1b27524a3d9dfaec4fcf8', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.xcodebuild/a06-ipad-normal-e206c0f3.log': '01ae749cdb701da73b6aa619e953913701d71ade234859e239418a22f8455e18', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/tests.json': '3e010ab7f4c820342a873edd8e6f50bbd4872ae457f951dda020a905675b8db3', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/provenance.json': '00739a53c8cf8e6038e69b80f84ae0d814a3fa8db1021ae73224e5d089fc85f5', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/summary.json': 'db6a83b5974f75d0f7aef5ce8b0483ef1e4200033dd7fa5dd47b518f0019cd45', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/ipad-normal-volume-overview-e206c0f3/run.log.gz': '2f10ab33b1297bf0172c183de49849563c3abc1f7246f29412582c370ed92730'}}
# Parent pins fresh actual readiness proof only after the owned iPad is dark.
INFRA_SHA256 = 'ea994d654c7e96a628b8b91d6c04e604a9657dc4ce8e899c8b6f93915d5b0089'
def walk(x):
 if isinstance(x,dict):
  yield x
  for v in x.values():yield from walk(v)
 elif isinstance(x,list):
  for v in x:yield from walk(v)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p): return json.loads(p.read_text())
def git(*args): return subprocess.check_output(['git','-C',str(ROOT),*args],text=True).strip()
def unchanged(): return git('rev-parse','HEAD')==REV and not git('status','--porcelain') and all(sha(ROOT/p)==h for p,h in PINS['files'].items())
def history_unchanged(): return all(sha(Path(p))==h for p,h in PINS['history'].items())
def unit_source_closure():
 changed={'DUNEUITests/Full/ActivityExerciseRegressionTests.swift','DUNEUITests/Regression/ChartInteractionRegressionUITests.swift'}
 return all(git('rev-parse', 'aeabdd7d88e89e2f87123ac63b76551b989eba6e:'+p)==git('rev-parse', REV+':'+p) for p in PINS['files'] if p not in changed)

def syncdir(p):
 fd=os.open(p,os.O_RDONLY)
 try: os.fsync(fd)
 finally: os.close(fd)
def durable_replace(path,obj):
 tmp=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
 with tmp.open('x') as f: json.dump(obj,f,ensure_ascii=False,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
 os.replace(tmp,path); syncdir(path.parent)
def main():
 if UID is None or NAME is None or COMPILE_PROOF is None or INFRA_SHA256 is None:
  raise SystemExit('A20 normal result and dark readiness proof must be pinned before dispatch')
 assert Path.cwd().resolve()==ROOT and unchanged() and history_unchanged() and unit_source_closure()
 assert all(sha(Path(p))==h for p,h in PINS['proofs'].items())
 registry=load(ROOT/'.codex-checks/worktree-simulators.json')
 assert registry==[dict(udid=UID,name=NAME,worktree=str(ROOT),preclone_verified=True)]
 if INFRA_SHA256 is None: raise SystemExit('Fresh dark-mode readiness proof is not pinned; dispatch prohibited')
 assert sha(INFRA)==INFRA_SHA256
 infra=load(INFRA)
 assert isinstance(infra['capturedAt'], (int, float)) and 0 <= time.time()-infra['capturedAt'] <= 1800
 assert infra['appearance']=='dark' and infra['ready'] is True and infra['ownedUID']==UID and infra['ownedCount']==1 and infra['state']=='Booted' and infra['available'] is True and infra['testsDispatched'] is False and infra['appLaunched'] is False and infra['approvalConsumed']==0
 hist=load(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-08e4e37289a3fdd7061d99ed.json'))
 assert hist['id']==ORIGINAL and len(hist['attempts'])==2 and all(a['status']=='failed' and SELECTOR in a['command'] for a in hist['attempts'])
 for a in hist['attempts']:
  assert sha(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline')/a['log'])==a['log_hash']
 first_log=Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline')/hist['attempts'][0]['log']
 assert "has no member 'count'" in first_log.read_text()
 result=load(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/evidence/ui-ipad-core-conditional-localized-period-failure/result.json'))
 assert result['status']=='failed' and result['counts']==dict(executed=6,passed=5,failed=1,skipped=0) and SELECTOR in result['requested_selectors']
 cases=[x for x in walk(load(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a06/evidence/ui-ipad-core-conditional-localized-period-failure/tests.json'))) if x.get('nodeType')=='Test Case']
 assert len(cases)==6 and sum(x.get('result')=='Passed' for x in cases)==5 and sum(x.get('result')=='Failed' for x in cases)==1
 assert any('testTrainingVolumeGoalContextAndPreviousRangeAcrossPeriods' in x.get('nodeIdentifier','') and x.get('result')=='Failed' for x in cases)
 # This explicit placeholder blocks dispatch until normal UI compile/PASS is pinned and reviewed.
 if COMPILE_PROOF is None: raise SystemExit('Current normal iPad compile/PASS proof not pinned; dispatch prohibited')
 assert COMPILE_PROOF['revision']==REV and COMPILE_PROOF['normal_selector']=='DUNEUITests/ChartInteractionRegressionUITests/testTrainingVolumeSurfaceShowsOverviewChartsAndTypeList' and COMPILE_PROOF['result_status']=='passed'
 for path,expected in COMPILE_PROOF['hashes'].items():assert sha(Path(path))==expected
 assert len(COMPILE_PROOF['hashes'])>=6
 assert all(COMPILE_PROOF[k] in COMPILE_PROOF['hashes'] for k in ('receipt','result','pipeline_log','raw_log','tests','provenance','summary','archived_log'))
 cp=load(Path(COMPILE_PROOF['receipt']));assert cp['id']=='pr893-ipad-normal-volume-overview' and cp['attempts'][-1]['status']=='success' and cp['attempts'][-1]['exit_code']==0 and COMPILE_PROOF['normal_selector'] in cp['attempts'][-1]['command'] and UID in cp['attempts'][-1]['command']
 normal=load(Path(COMPILE_PROOF['result']));assert normal['status']=='passed' and normal['run_exit_status']==0 and normal['requested_selectors']==[COMPILE_PROOF['normal_selector']] and normal['counts']==dict(executed=1,passed=1,failed=0,skipped=0) and not normal['required_selectors_missing']
 assert load(Path(COMPILE_PROOF['provenance']))['revision']==REV and load(Path(COMPILE_PROOF['provenance']))['source_worktree_dirty'] is False
 assert cp['attempts'][-1]['log_hash']==sha(Path(COMPILE_PROOF['pipeline_log'])) and '** TEST SUCCEEDED **' in Path(COMPILE_PROOF['raw_log']).read_text()
 test_data=load(Path(COMPILE_PROOF['tests']));assert any(d.get('deviceId')==UID for d in test_data['devices'])
 cases=[x for x in walk(test_data) if x.get('nodeType')=='Test Case'];assert len(cases)==1 and cases[0]['nodeIdentifier']==COMPILE_PROOF['normal_selector'].removeprefix('DUNEUITests/')+'()' and cases[0]['result']=='Passed'
 unit=load(ROOT/'.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/pipeline-receipt.json')
 assert unit['id']=='pr893-calendar-volume-unit' and unit['attempts'][-1]['status']=='success' and unit['attempts'][-1]['exit_code']==0
 summary=load(ROOT/'.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/summary.json')
 assert summary['result']=='Passed' and summary['passedTests']==34 and summary['failedTests']==0 and summary['skippedTests']==0
 assert load(ROOT/'.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/provenance.json')['revision']=='aeabdd7d88e89e2f87123ac63b76551b989eba6e'
 with (ROOT/'.deriveddata/ui-tests/info.plist').open('rb') as f: assert plistlib.load(f)['WorkspacePath']==str(ROOT/'DUNE/DUNE.xcodeproj')
 inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True,timeout=20))
 matches=[d for group in inventory['devices'].values() for d in group if d['udid']==UID]
 assert len(matches)==1 and matches[0]['name']==NAME and matches[0]['state']=='Booted' and matches[0]['isAvailable'] is True
 appearance=subprocess.check_output(['xcrun','simctl','ui',UID,'appearance'],text=True,timeout=20).strip()
 assert appearance=='dark', 'Owned iPad must actually be in dark appearance'
 proxy_record=ROOT/'.codex-checks/pipeline'/('check-'+hashlib.sha256(PROXY.encode()).hexdigest()[:24]+'.json')
 entry=ROOT/'.codex-checks/a06/ipad-goal-approved-extra-e206c0f3-entry.log'
 receipt=ROOT/'.xcodebuild/a06-ipad-goal-approved-extra-e206c0f3.log.result.json'
 assert not MARKER.exists() and not proxy_record.exists() and not entry.exists() and not receipt.exists()
 proof=dict(authorization='모두 1회 추가 허용 알아서 처리하고 머지까지 완료',approvalGroup=GROUP,originalPipelineID=ORIGINAL,proxyRecordID=PROXY,selector=SELECTOR,revision=REV,device=UID,approvedExtra=1,consumed=1,remaining=0,status='running',started=time.time(),historyPins=PINS['history'],infraProof=str(INFRA),infraSHA256=INFRA_SHA256,appearanceReadback=appearance,compilePins=COMPILE_PROOF,reviewPins=PINS['proofs'])
 with LEDGER.with_name('user-approval-ledger.lock').open('a+b') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  ledger=load(LEDGER); frozen=json.loads(json.dumps(ledger)); group=ledger[GROUP]; slot=group['perCase']['A06_iPadGoal']
  logical=ORIGINAL+'::'+SELECTOR
  assert logical not in group.get('consumedLogicalCases',{})
  assert group['authorization']==proof['authorization'] and (slot['approvedExtra'],slot['consumed'],slot['remaining'])==(1,0,1)
  assert not MARKER.exists() and unchanged() and history_unchanged() and all(sha(Path(p))==h for p,h in PINS['proofs'].items()) and sha(INFRA)==INFRA_SHA256
  assert 0 <= time.time()-infra['capturedAt'] <= 1800
  appearance=subprocess.check_output(['xcrun','simctl','ui',UID,'appearance'],text=True,timeout=20).strip();assert appearance=='dark';proof['appearanceReadback']=appearance
  slot.update(consumed=1,remaining=0,marker=str(MARKER),proxyRecordID=PROXY,device=UID,executionSource=REV,executionSelector=SELECTOR,originalLogicalID=ORIGINAL)
  group.setdefault('consumedLogicalCases',{})[logical]=str(MARKER)
  assert all(ledger[k]==v for k,v in frozen.items() if k!=GROUP)
  assert all(group[k]==v for k,v in frozen[GROUP].items() if k not in ('perCase','consumedLogicalCases'))
  assert all(group['perCase'][k]==v for k,v in frozen[GROUP]['perCase'].items() if k!='A06_iPadGoal')
  assert all(group['consumedLogicalCases'][k]==v for k,v in frozen[GROUP].get('consumedLogicalCases',{}).items())
  durable_replace(LEDGER,ledger)
  with MARKER.open('x') as f: json.dump(proof,f,ensure_ascii=False,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
  syncdir(MARKER.parent)
 command=[sys.executable,'-B','scripts/codex-pipeline.py','run',PROXY,'--context','A06-e206c0f3-approved-extra-original-history-preserved','--scope','One approved additional execution of exact original iPad dark normal-text goal selector; no retry','--timeout','1250','--',sys.executable,'-B','scripts/lib/simulator-test-lock.py',str(ROOT),'--','scripts/test-ui.sh','--no-regen','--stream-log','--test-plan','DUNEUITests-DesignCapture','--simulator-udid',UID,'--only-testing',SELECTOR,'--log-file','.xcodebuild/a06-ipad-goal-approved-extra-e206c0f3.log']
 env=dict(os.environ,DUNE_SIM_TEST_LOCK_SCOPE='worktree',DUNE_SIM_TEST_LOCK_WAIT_SECONDS='0',DUNE_UI_TEST_WALL_TIMEOUT='1200',DAILVE_UI_TEST_DERIVED_DATA_DIR='.deriveddata/ui-tests')
 try:
  with entry.open('xb') as f: result=subprocess.run(command,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1280)
  proof['exitCode']=result.returncode; native=load(receipt) if receipt.is_file() else {}; proof['nativeResult']=native
  proof['sourceUnchanged']=unchanged(); proof['originalHistoryUnchanged']=history_unchanged()
  proof['status']='passed' if result.returncode==0 and proof['sourceUnchanged'] and proof['originalHistoryUnchanged'] and native.get('status')=='passed' and native.get('run_exit_status')==0 and native.get('counts')==dict(executed=1,passed=1,failed=0,skipped=0) and native.get('requested_selectors')==[SELECTOR] and not native.get('required_selectors_missing') else 'failed'
 except BaseException as exc: proof.update(status='failed',error=repr(exc))
 finally:
  try: proof['sourceUnchanged']=unchanged(); proof['originalHistoryUnchanged']=history_unchanged()
  except BaseException as exc: proof.update(status='failed',verificationError=repr(exc))
  if not proof.get('sourceUnchanged') or not proof.get('originalHistoryUnchanged'): proof['status']='failed'
  proof['completed']=time.time(); durable_replace(MARKER,proof)
 print(json.dumps(proof,ensure_ascii=False)); return 0 if proof['status']=='passed' else 1
if __name__=='__main__': sys.exit(main())
