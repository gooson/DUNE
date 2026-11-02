#!/usr/bin/env python3
"""Prepared A07 one-shot guard. Independent review and readiness proof required before execution."""
if not __debug__:
 raise SystemExit('Safety assertions require non-optimized Python')
import fcntl, hashlib, json, os, plistlib, subprocess, sys, time, uuid
from pathlib import Path
ROOT=Path('/Users/shanks/.codex/worktrees/detail-redesign-a07/Health')
REV='3f2ff74bd1effb6a356cace29e77a20353cbea96'
UID='24958C4B-4C06-41E6-8F69-27BA864B37E7'
NAME='iPad mini (A20 Pro)-wt-Health-detail-redesign-a07-5b4b7e5bf912'
SELECTOR='DUNEUITests/ActivityExerciseRegressionTests/testExerciseTypeDetailAtMaximumAccessibilityTextSize'
ORIGINAL='a07-ui-ipad-types-and-dark-AX'
GROUP='2026-11-02-pending-extra-once'
PROXY='pr894-ipad-max-approved-extra-once-3f2ff74b'
LEDGER=Path('/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/detail-rollout/user-approval-ledger.json')
MARKER=ROOT/'.codex-checks/a07/ipad-max-approved-extra-3f2ff74b-consumed.json'
INFRA=ROOT/'.codex-checks/a07/ipad-max-a20-infra-3f2ff74b/proof.json'
PINS={'files': {'DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift': '096c21309dae0485530f8721980bbe34f090a011deecd88cbb8f445ec399ba91', 'DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailViewModel.swift': '485d3f95757d9e27128ebce9f125b60a2c4259f2610ecf66a6042e108187a31e', 'DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift': 'bbe5234af78cabc32e62f1da17deedb02c3cc02df82d4d287fc4e83e869ad075', 'DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift': '92d7d9303b167161c02456ff7b499ce42861bc5ab73cfa5ebe5da6886f5d36bd', 'DUNE/Domain/Models/TrainingVolume.swift': 'e85f82e3ff6d18d9e9abdf795e381147a208de9f19b655e2e439595812258bcb', 'DUNE/Presentation/Activity/ActivityView.swift': '9f985b8a15aff300eae065162153060d2c5e8e7cba54213035b0bc5d2ba01cc2', 'DUNE/App/ContentView.swift': '1f99acd7c7ae1f91f300d3f82de18f255ecb7061ebe9143cd7c1bffe76229cc0', 'DUNE/App/TestDataSeeder.swift': 'aeec211b427297c1fcca5e2573515182076e38570bdbdf9e3048de14885e76bb', 'DUNEUITests/Full/ActivityExerciseRegressionTests.swift': 'b77ed5d43620a898247e5552624cc84a8f16edff33923f8d3b552594f47c7bfd', 'DUNEUITests/Full/ExerciseTypeHealthKitVariantUITests.swift': '81ced0321881ea54dcf9c54c6ffeb8eb0555bc1e11d64afb7f7c8d4c8aad46a1', 'DUNEUITests/Helpers/UITestBaseCase.swift': '1299e3efbe08b78ebcda033b0abf0b31d1d9635b2822e45a04b5df840b3f7f1e', 'DUNEUITests/Helpers/UITestHelpers.swift': '1543b51342c33b2d607f910fe4f43cbf382d578c9331623b911f96603b2cef6c', 'DUNEUITests/DUNEUITests-DesignCapture.xctestplan': '43b6845f3a9ce24fa8c2a9efeb27d569e0ee2cd81a1d87fe7283aeb091588256', 'DUNETests/TrainingVolumeAnalysisServiceTests.swift': '25a75007dbdc7dfce6a086d7569919fac418209a6e447c1f442eef10f846f16c', 'DUNETests/TrainingVolumeViewModelTests.swift': '130c62b792e0eefde639ebbb651ec18421b2e1f90446d8d9959391e1d8685f80', 'DUNETests/ExerciseTypeDetailViewModelTests.swift': 'b07880e2be0f933c8890e84fb6966e373012591c4e37867563a8dd35440497d5', 'scripts/test-ui.sh': '2289203358eebb3bd32522b731623103925c11bfffda65b273e55f0a02a54d59', 'scripts/codex-pipeline.py': '2d12b83aefb64bf03ecb4551faf00dff9be3f71667bf243f33d4390192bda53c', 'scripts/lib/simulator-test-lock.py': 'f1f57a001e1b7414da39b8e7085ee7f4d68c23428848c208e00ea40e81e9a407', 'DUNE/Presentation/Activity/TrainingVolume/Components/ActivityRingView.swift': 'e455cada7dd6ee2675cd18f489685ca6a054dd7476701d4a046601ff8da465d7', 'DUNE/Presentation/Activity/TrainingVolume/Components/ExerciseTypeSummaryRow.swift': 'e9de6a313b501c85912622fd765850fafd28a506d0219b4cef7f36f0bddb596e', 'DUNE/Presentation/Activity/TrainingVolume/Components/PeriodComparisonView.swift': '543e3956648f6a07bbcec5b85d2c33b562e910f6a10f463c680d0ede3cf75aa3', 'DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift': 'a67d65468bfdad2f31c7074309eacce8f01def6d15346d2aa39b2f2fb6f1d91e', 'DUNE/Presentation/Activity/TrainingVolume/Components/TrainingVolumeSummaryCard.swift': 'd5a95161a626c2a8a531f8e1653cbef1820475df80a6fd17d443249ae7a325c1', 'DUNE/Presentation/Activity/TrainingVolume/Components/VolumeDonutChartView.swift': '05b7ab22310360aee4d39710d498bb0dfa3c8f161cc167506fad1b79a90fdb46', 'DUNE/Domain/Models/Equipment.swift': 'ca0cc79034ba7835dfa0ec39dc0c24d2529bf01ac3c07a5345dfa1ccf2260fe2', 'DUNE/Presentation/Shared/Extensions/Equipment+View.swift': '6eeda7b91f6b5893d55e1c88d59a6f1e8c0eeb8cf4c5da2805d7a91743ef63b9', 'DUNE/Presentation/Shared/Components/ChangeBadge.swift': 'c738dd68fc609f53f93a0bd6b8067bc9009c4e8ba551e658cee1294319a3a325', 'DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift': 'c480b3e8ae4a966149f953ff630e75aa443b1f1d71280e922880600c69ba8d13'}, 'history': {'/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-a6828cab68e5430cd374e0a4.json': '1f827db523bd641cba5dc80f34ad8b8676a003b7750fb3c7b575ce264d5b3658', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-a6828cab68e5430cd374e0a4-10766d5f8e6c416ea80212e6c2ca37c2.log': 'dedc5d5e686ea0684feb4fcf14a2baec3cda71cd9e238fc790fda40913e9687b', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-a6828cab68e5430cd374e0a4-4a2981dcc326474ab8b160748dd6b6cf.log': '2d947ad32469d24142d5b0b035eee7877a268973e4aebc14d8f7f0641b9679ee', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/retry-proof/cause-remediation.json': 'd05cbeee79327113e60e6b7fef019bcb05e3e5015a78fb69ac352d895b790fe8', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-normal-types-and-initial-AX-failure/result.json': '12afd8675dbc7f3543dfa75aba4ad8521e446bd9fd44855d5b8d31c7fd83c868', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-normal-types-and-initial-AX-failure/tests.json': '0cff39d6d8004b0fa599b12da79a0a7f701ffb6009ce0d2bb1800622a213331c', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-normal-types-and-initial-AX-failure/summary.json': '9c5952bc4680f0ce93914c8dda2b4b0b4aa8ada8999b4773f4f6f4260bdebd04', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-normal-types-and-initial-AX-failure/provenance.json': '14a6ef30b787e2bdb969c7637d408f06c5758b42677b925add21243c38d6bf55', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-normal-types-and-initial-AX-failure/run.log.gz': '9c26420a33d3117f3fcc1c30a32f06eedce2a212f91aa01827df125ab2790414', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-conditional-AX-entry-viewport-failure/result.json': '52b497305b9d553d563245dca5bebf66d4049da5f65673929a35dd18e5473a77', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-conditional-AX-entry-viewport-failure/tests.json': 'c2c690b0f067f2a829ab23300370f1bf1f88a93fd2a389627cbd168dce7f3e1d', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-conditional-AX-entry-viewport-failure/summary.json': 'b81965b3d700d74f41964d749149d898e16c06bae40ccd0cabf41127fcfd27a4', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-conditional-AX-entry-viewport-failure/provenance.json': 'bf0bc8b3ab443ef0178a9fde7bc496ec165221348d90fc921bb8a2eabf8a92ce', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence/ui-ipad-conditional-AX-entry-viewport-failure/run.log.gz': '83d71dc462e6a571e9d2314f26c846ad8420a8c0cb5a3f45d8f5e6852c1d4efc'}, 'proofs': {'/private/tmp/pr894-review-security.md': 'bc207ca3f2667460b82eb52b81d105e8b3b24eaae1c450418e7f19ab07d12d04', '/private/tmp/pr894-review-performance.md': '1ba3cf70ca244d180a39fc215cfcedc946b80dc9c6116d3e1a5171dcce355acd', '/private/tmp/pr894-review-data.md': 'a941e9639762ee146b7e31b95ae13648b2e9ec636a861437a36d8ecd9a34e5de', '/private/tmp/pr894-review-architecture.md': '0380722277fb7e554d7e77d23cc11352a718e6cebb86afa70f74bce970d7ab27', '/private/tmp/pr894-review-simplicity.md': '0da21a7557941d845c2d86bddb2023fe7e99cdc3356edb5a46686a6429f16ea7', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/review-resolution.md': '9c4b37cda010b41339b3e3308db4b205e485dade6df9f0d7eabacd9d0e77b496', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/summary.json': 'dce6f16dc7c914b50ef93d1dfe7436d31f7e963ff8d824c6822f428a62f52c31', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/tests.json': 'bd4b0b778d04a39a6b200c53adbc8ed8eb975bc7b79e3920780d71def28c2b84', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/pipeline-receipt.json': 'ab9f1b05567c763cbba5316f59c2576eeaeb500bdf91266f80e453503bfd8feb', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/pipeline-output.log': '39edb3b0c128a6cc35cb2cc0537c36f0eb2e240651f25da7a090e35132aa7a2d', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/provenance.json': 'a37013d4af178a1c1df5dd65192c815cb034ab59a7273bf3a3f42a8d137c950c', '/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d/run.log.gz': '28b49e8ebf029715fe99db7333821e10deb11ea164669a879a73dbc81bce017a', '/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/detail-rollout/quality-queue/pr893/ci-final-jobs.json': 'b1eab07a2da25a4bd456e05240e2414937add9c8449e32535bff2895df3058f9'}}
# Parent must add independently verified current normal-run compile receipt and hashes.
COMPILE_PROOF = {'revision': '3f2ff74bd1effb6a356cace29e77a20353cbea96', 'normal_selectors': ['DUNEUITests/ActivityExerciseRegressionTests/testExerciseTypeDetailShowsTrendSurface', 'DUNEUITests/ExerciseTypeHealthKitVariantUITests/testExistingHealthKitTypesOpenWeekDetailAndCapture'], 'result_status': 'passed', 'receipt': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/pipeline/check-4c5b4c69cc877298ce6572f5.json', 'result': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.xcodebuild/a07-ipad-normal-types-3f2ff74b.log.result.json', 'pipeline_log': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/pipeline/check-4c5b4c69cc877298ce6572f5-641fca8b131d42e7813ade3d3601cfc6.log', 'raw_log': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.xcodebuild/a07-ipad-normal-types-3f2ff74b.log', 'tests': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/tests.json', 'provenance': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/provenance.json', 'summary': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/summary.json', 'archived_log': '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/run.log.gz', 'hashes': {'/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/pipeline/check-4c5b4c69cc877298ce6572f5.json': '4f7d6ae644dafd685bc874285630f22e8905b27fac6956abc9a7b8ce4cd19f6d', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.xcodebuild/a07-ipad-normal-types-3f2ff74b.log.result.json': 'bfaa48d5792080de0be643e84c41729a5db1f6dc7a146bc30927163b62dbbf9e', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/pipeline/check-4c5b4c69cc877298ce6572f5-641fca8b131d42e7813ade3d3601cfc6.log': '42e649b756ce2195e1665c3a73291b52466d02040daec400357f1f54ab79748f', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.xcodebuild/a07-ipad-normal-types-3f2ff74b.log': 'c3638087874602292845b78a324b2d88ecf10b0dc3908d8183c5a22f3f77d001', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/tests.json': '90e6fff4742c5c614650428e53a2a16c84b81b6674d73a27ae040bad912dd38e', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/provenance.json': 'd330c1f7c4a82ad45caa9fd6200805a62fe9a125e971893116770ee5dda206ec', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/summary.json': '6bd2ac7e7946f95c451fb76b9d44fc309359559b9bb29695e3f4ff2ada02cb94', '/Users/shanks/.codex/worktrees/detail-redesign-a07/Health/.codex-checks/a07/evidence/ipad-normal-manual-hk-types-3f2ff74b/run.log.gz': '3f95c3c3b22c85dfe2ab4966c4241043a3baf17d95b4cd2f96318b63adf4caa9'}}
# Parent pins fresh actual readiness proof only after the owned iPad is dark.
INFRA_SHA256 = '69c60b0c92e95dcee2eda7badc95ee2e4d3d9b59ccf68b149f247b3bb89b54f2'
INFRA_APPEARANCE_SHA256 = '3d1cfa6deae9416413e1ad818dbc4dcb3169a755a4d080780d403a46c89fa122'
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
  raise SystemExit('A20 device, A20 normal result and readiness proof must be pinned before dispatch')
 assert Path.cwd().resolve()==ROOT and unchanged() and history_unchanged()
 assert all(sha(Path(p))==h for p,h in PINS['proofs'].items())
 registry=load(ROOT/'.codex-checks/worktree-simulators.json')
 assert registry==[dict(udid=UID,name=NAME,worktree=str(ROOT),preclone_verified=True)]
 if INFRA_SHA256 is None: raise SystemExit('Fresh dark-mode readiness proof is not pinned; dispatch prohibited')
 assert sha(INFRA)==INFRA_SHA256
 assert sha(INFRA.parent/'appearance-after.txt')==INFRA_APPEARANCE_SHA256 and (INFRA.parent/'appearance-after.txt').read_text().strip()=='dark'
 infra=load(INFRA)
 assert isinstance(infra['capturedAt'], (int, float)) and 0 <= time.time()-infra['capturedAt'] <= 1800
 assert infra['appearance']=='dark' and infra['ready'] is True and infra['ownedUID']==UID and infra['ownedCount']==1 and infra['state']=='Booted' and infra['available'] is True and infra['testsDispatched'] is False and infra['appLaunched'] is False and infra['approvalConsumed']==0
 hist=load(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-a6828cab68e5430cd374e0a4.json'))
 assert hist['id']==ORIGINAL and len(hist['attempts'])==2 and all(a['status']=='failed' and SELECTOR in a['command'] for a in hist['attempts'])
 for a in hist['attempts']:
  assert sha(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline')/a['log'])==a['log_hash']
 archives=[Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/a07/evidence')/n for n in ('ui-ipad-normal-types-and-initial-AX-failure','ui-ipad-conditional-AX-entry-viewport-failure')]
 for archive,counts,revision in zip(archives,(dict(executed=3,passed=2,failed=1,skipped=0),dict(executed=1,passed=0,failed=1,skipped=0)),('b2b5ae66','25ad7839')):
  result=load(archive/'result.json');assert result['status']=='failed' and result['counts']==counts and SELECTOR in result['requested_selectors'] and load(archive/'provenance.json')['revision']==revision
  cases=[x for x in walk(load(archive/'tests.json')) if x.get('nodeType')=='Test Case'];assert len(cases)==counts['executed'] and sum(x.get('result')=='Passed' for x in cases)==counts['passed'] and any('testExerciseTypeDetailAtMaximumAccessibilityTextSize' in x.get('nodeIdentifier','') and x.get('result')=='Failed' for x in cases)
 # This explicit placeholder blocks dispatch until normal UI compile/PASS is pinned and reviewed.
 if COMPILE_PROOF is None: raise SystemExit('Current normal iPad compile/PASS proof not pinned; dispatch prohibited')
 assert COMPILE_PROOF['revision']==REV and COMPILE_PROOF['normal_selectors']==['DUNEUITests/ActivityExerciseRegressionTests/testExerciseTypeDetailShowsTrendSurface','DUNEUITests/ExerciseTypeHealthKitVariantUITests/testExistingHealthKitTypesOpenWeekDetailAndCapture'] and COMPILE_PROOF['result_status']=='passed'
 for path,expected in COMPILE_PROOF['hashes'].items():assert sha(Path(path))==expected
 assert len(COMPILE_PROOF['hashes'])>=6
 assert all(COMPILE_PROOF[k] in COMPILE_PROOF['hashes'] for k in ('receipt','result','pipeline_log','raw_log','tests','provenance','summary','archived_log'))
 cp=load(Path(COMPILE_PROOF['receipt']));assert cp['id']=='pr894-ipad-normal-manual-and-hk-types' and cp['attempts'][-1]['status']=='success' and cp['attempts'][-1]['exit_code']==0 and all(x in cp['attempts'][-1]['command'] for x in COMPILE_PROOF['normal_selectors']) and UID in cp['attempts'][-1]['command']
 normal=load(Path(COMPILE_PROOF['result']));assert normal['status']=='passed' and normal['run_exit_status']==0 and normal['requested_selectors']==COMPILE_PROOF['normal_selectors'] and normal['counts']==dict(executed=2,passed=2,failed=0,skipped=0) and not normal['required_selectors_missing']
 assert load(Path(COMPILE_PROOF['provenance']))['revision']==REV and load(Path(COMPILE_PROOF['provenance']))['source_worktree_dirty'] is False
 assert cp['attempts'][-1]['log_hash']==sha(Path(COMPILE_PROOF['pipeline_log'])) and '** TEST SUCCEEDED **' in Path(COMPILE_PROOF['raw_log']).read_text()
 test_data=load(Path(COMPILE_PROOF['tests']));assert any(d.get('deviceId')==UID for d in test_data['devices'])
 cases=[x for x in walk(test_data) if x.get('nodeType')=='Test Case'];assert len(cases)==2 and all(x['result']=='Passed' for x in cases) and {x['nodeIdentifier'] for x in cases}=={x.removeprefix('DUNEUITests/')+'()' for x in COMPILE_PROOF['normal_selectors']}
 unitroot=Path('/Users/shanks/.codex/worktrees/detail-redesign-a06/Health/.codex-checks/a06/evidence/calendar-volume-unit-aeabdd7d')
 summary=load(unitroot/'summary.json');assert summary['result']=='Passed' and summary['passedTests']==34 and summary['failedTests']==summary['skippedTests']==0
 assert load(unitroot/'provenance.json')['revision']=='aeabdd7d88e89e2f87123ac63b76551b989eba6e'
 main='40c035ee71507bb1cda5751287883722071c438c'
 shared=['DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailViewModel.swift','DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift','DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift','DUNE/Domain/Models/TrainingVolume.swift','DUNETests/TrainingVolumeAnalysisServiceTests.swift','DUNETests/TrainingVolumeViewModelTests.swift','DUNETests/ExerciseTypeDetailViewModelTests.swift']
 assert all(git('rev-parse',main+':'+p)==git('rev-parse',REV+':'+p) for p in shared)
 ci=load(Path('/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/detail-rollout/quality-queue/pr893/ci-final-jobs.json'))
 assert ci['commit']=='844dacaae8d1bed1c467b92bb3f21d7b07e449a4'
 jobs={job['id']:job for run in ci['runs'] for job in run['response']['jobs']}
 assert all(jobs[i]['status']=='completed' and jobs[i]['conclusion']=='success' and jobs[i]['run_id']==run_id for i,run_id in {125522549998:41516869602,125522548388:41516869679,125522548056:41516869679}.items())
 with (ROOT/'.deriveddata/ui-tests/info.plist').open('rb') as f: assert plistlib.load(f)['WorkspacePath']==str(ROOT/'DUNE/DUNE.xcodeproj')
 inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True,timeout=20))
 matches=[d for group in inventory['devices'].values() for d in group if d['udid']==UID]
 assert len(matches)==1 and matches[0]['name']==NAME and matches[0]['state']=='Booted' and matches[0]['isAvailable'] is True
 appearance=subprocess.check_output(['xcrun','simctl','ui',UID,'appearance'],text=True,timeout=20).strip()
 assert appearance=='dark', 'Owned iPad must actually be in dark appearance'
 proxy_record=ROOT/'.codex-checks/pipeline'/('check-'+hashlib.sha256(PROXY.encode()).hexdigest()[:24]+'.json')
 entry=ROOT/'.codex-checks/a07/ipad-max-approved-extra-3f2ff74b-entry.log'
 receipt=ROOT/'.xcodebuild/a07-ipad-max-approved-extra-3f2ff74b.log.result.json'
 assert not MARKER.exists() and not proxy_record.exists() and not entry.exists() and not receipt.exists()
 proof=dict(authorization='모두 1회 추가 허용 알아서 처리하고 머지까지 완료',approvalGroup=GROUP,originalPipelineID=ORIGINAL,proxyRecordID=PROXY,selector=SELECTOR,revision=REV,device=UID,approvedExtra=1,consumed=1,remaining=0,status='running',started=time.time(),historyPins=PINS['history'],infraProof=str(INFRA),infraSHA256=INFRA_SHA256,appearanceReadback=appearance,compilePins=COMPILE_PROOF,reviewPins=PINS['proofs'])
 with LEDGER.with_name('user-approval-ledger.lock').open('a+b') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  ledger=load(LEDGER); frozen=json.loads(json.dumps(ledger)); group=ledger[GROUP]; slot=group['perCase']['A07_iPadMAX']
  logical=ORIGINAL+'::'+SELECTOR
  assert logical not in group.get('consumedLogicalCases',{})
  assert group['authorization']==proof['authorization'] and (slot['approvedExtra'],slot['consumed'],slot['remaining'])==(1,0,1)
  assert not MARKER.exists() and unchanged() and history_unchanged() and all(sha(Path(p))==h for p,h in PINS['proofs'].items()) and sha(INFRA)==INFRA_SHA256 and sha(INFRA.parent/'appearance-after.txt')==INFRA_APPEARANCE_SHA256
  assert 0 <= time.time()-infra['capturedAt'] <= 1800
  appearance=subprocess.check_output(['xcrun','simctl','ui',UID,'appearance'],text=True,timeout=20).strip();assert appearance=='dark';proof['appearanceReadback']=appearance
  slot.update(consumed=1,remaining=0,marker=str(MARKER),proxyRecordID=PROXY,device=UID,executionSource=REV,executionSelector=SELECTOR,originalLogicalID=ORIGINAL)
  group.setdefault('consumedLogicalCases',{})[logical]=str(MARKER)
  assert all(ledger[k]==v for k,v in frozen.items() if k!=GROUP)
  assert all(group[k]==v for k,v in frozen[GROUP].items() if k not in ('perCase','consumedLogicalCases'))
  assert all(group['perCase'][k]==v for k,v in frozen[GROUP]['perCase'].items() if k!='A07_iPadMAX')
  assert all(group['consumedLogicalCases'][k]==v for k,v in frozen[GROUP].get('consumedLogicalCases',{}).items())
  durable_replace(LEDGER,ledger)
  with MARKER.open('x') as f: json.dump(proof,f,ensure_ascii=False,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
  syncdir(MARKER.parent)
 command=[sys.executable,'-B','scripts/codex-pipeline.py','run',PROXY,'--context','A07-3f2ff74b-approved-extra-original-history-preserved','--scope','One approved additional execution of exact original iPad dark MAX exercise type selector; no retry','--timeout','1250','--',sys.executable,'-B','scripts/lib/simulator-test-lock.py',str(ROOT),'--','scripts/test-ui.sh','--no-regen','--stream-log','--test-plan','DUNEUITests-DesignCapture','--simulator-udid',UID,'--only-testing',SELECTOR,'--log-file','.xcodebuild/a07-ipad-max-approved-extra-3f2ff74b.log']
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
