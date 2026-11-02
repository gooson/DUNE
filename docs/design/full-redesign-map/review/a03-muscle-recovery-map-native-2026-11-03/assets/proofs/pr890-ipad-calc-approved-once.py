#!/usr/bin/env python3
"""Prepared A03 one-shot guard. Independent review and readiness proof required before execution."""
if not __debug__:
 raise SystemExit('Safety assertions require non-optimized Python')
import fcntl, hashlib, json, os, subprocess, sys, time, uuid
from pathlib import Path
ROOT=Path('/Users/shanks/.codex/worktrees/detail-redesign-a03/Health')
REV='a2268fe08bbe181777ee3454bc3befc8659eda97'
UID='0479255E-D576-45F2-BAB8-C5EC72A8C173'
NAME='iPad Pro 13-inch (M5)-wt-Health-detail-redesign-a03-e8e491491d39'
SELECTOR='DUNEUITests/ActivityMuscleMapRegressionTests/testMuscleMapDetailKeeps2DSelectionWith3DEntryDisabled'
ORIGINAL='a03-ui-ipad-2d-detail-and-calculation'
GROUP='2026-11-02-pending-extra-once'
PROXY='pr890-ipad-calculation-approved-extra-once-a2268fe0'
LEDGER=Path('/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/detail-rollout/user-approval-ledger.json')
MARKER=ROOT/'.codex-checks/a03/ipad-calc-approved-extra-a2268fe0-consumed.json'
INFRA=ROOT/'.codex-checks/a03/ipad-calc-infra-a2268fe0/proof.json'
PINS={'files': {'DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift': 'be598485c8c4cb2161e68c48898dd6eaa2516d1be25abf558eb1c97e20ed531f', 'DUNE/Presentation/Activity/Components/MuscleRecoveryMapView.swift': '415f6aef800abd25d5fd7b889b7dae6441386c9f32c3245909c4c015795fab14', 'DUNE/Presentation/Activity/MuscleMap/Components/RecoveryOverviewSection.swift': '665c94f5e8ddd78f1e79008519a703a427953f3b694cedbcc62ad1f4974908f5', 'DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailViewModel.swift': '761c8f13add5a8b32d2c9e0a8e9489daa3e5053a38e7268c16c19533efdf1964', 'DUNE/Presentation/Activity/ActivityView.swift': '6fe3269bbc25cf414aa36f4a4c496a676faa1cc6c147e355d1714af6a86229db', 'DUNE/App/ContentView.swift': '1f99acd7c7ae1f91f300d3f82de18f255ecb7061ebe9143cd7c1bffe76229cc0', 'DUNE/App/TestDataSeeder.swift': 'aeec211b427297c1fcca5e2573515182076e38570bdbdf9e3048de14885e76bb', 'DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift': 'abc3b2da6f606b294fd8b0766c9a7a6308d2288c229f26fb7f3946259cbfe24a', 'DUNEUITests/Helpers/UITestBaseCase.swift': '1299e3efbe08b78ebcda033b0abf0b31d1d9635b2822e45a04b5df840b3f7f1e', 'DUNEUITests/Helpers/UITestHelpers.swift': '1543b51342c33b2d607f910fe4f43cbf382d578c9331623b911f96603b2cef6c', 'scripts/test-ui.sh': '2289203358eebb3bd32522b731623103925c11bfffda65b273e55f0a02a54d59', 'scripts/codex-pipeline.py': '2d12b83aefb64bf03ecb4551faf00dff9be3f71667bf243f33d4390192bda53c', 'scripts/lib/simulator-test-lock.py': 'f1f57a001e1b7414da39b8e7085ee7f4d68c23428848c208e00ea40e81e9a407'}, 'proofs': {'/Users/shanks/.codex/worktrees/detail-redesign-a03/Health/.codex-checks/pipeline/check-57c78bc98298efab1256b643.json': '1930e8d42e0ba1fafd3335d83ed362be7c7d58a1bc4c4a9c767a9714d3bee836', '/Users/shanks/.codex/worktrees/detail-redesign-a03/Health/.codex-checks/pipeline/check-57c78bc98298efab1256b643-7cb537df0bea4b039cab76efa41feaa4.log': 'c2339ba1436d0a5cfe1395106a0e6b7957b71ca945177fa0a15e14394b48ab2f', '/private/tmp/pr890-a03-compile-a2268fe0.log': 'cccf4e9b375a1c486886d5d229d4c025769c3da72a9275cdc715d5e919c573d6', '/private/tmp/pr890-review-data.md': '465aee21d6987e0638ae19807694a09b80d08d92536fd0a7db030623ca47e3fa', '/private/tmp/pr890-review-architecture.md': '9d39cf91fa4a6e3f954322c7b36fd4ed68782e2e5c1c4f3ab72d76df4da7562f', '/private/tmp/pr890-review-performance.md': 'eba29c019b15761550aff7a584bf6570cebf339f578948ee7cf0ee89b5ecfd16', '/private/tmp/pr890-review-security.md': '16db8a3e623a1d38b83b4d0efed4b36e6512d674c3ec9c71aef1e11e90d17490', '/private/tmp/pr890-review-simplicity.md': '04b09b4f8c99086455a735d4438310b44dfae4d557b6c6fd54af535ca3a2f4d4'}, 'history': {'/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-55022da0cc71d14c40be714e-4c9385c7f5bc41bc8f20a098b23d3cf1.log': '5edc7507afd80cfed0356dddcc436f4726a20e285f0edc97e0c2db4c4e1e4a67', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-55022da0cc71d14c40be714e-71f770e584474288b85a6a895425a8ff.log': '28318b095d10f16d31555ccc26757a4025454ef1f93a6565fb06c00f7a2242e7', '/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-55022da0cc71d14c40be714e.json': '1e969833583234dcc7c130c6c2fac974247bd3a0cdb6566f90fb40a4f95501b7'}}
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
 assert Path.cwd().resolve()==ROOT and unchanged() and history_unchanged()
 assert all(sha(Path(p))==h for p,h in PINS['proofs'].items())
 registry=load(ROOT/'.codex-checks/worktree-simulators.json')
 assert registry==[dict(udid=UID,name=NAME,worktree=str(ROOT),preclone_verified=True)]
 infra=load(INFRA)
 assert infra['ready'] is True and infra['ownedUID']==UID and infra['ownedCount']==1 and infra['state']=='Booted' and infra['available'] is True and infra['testsDispatched'] is False and infra['appLaunched'] is False and infra['approvalConsumed']==0
 hist=load(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline/check-55022da0cc71d14c40be714e.json'))
 assert hist['id']==ORIGINAL and len(hist['attempts'])==2 and all(a['status']=='failed' and SELECTOR in a['command'] for a in hist['attempts'])
 for a in hist['attempts']:
  assert sha(Path('/Users/shanks/.codex/worktrees/detail-redesign-validation/Health/.codex-checks/pipeline')/a['log'])==a['log_hash']
 compile=load(ROOT/'.codex-checks/pipeline/check-57c78bc98298efab1256b643.json')
 assert compile['id']=='pr890-observed-recovery-ui-compile' and len(compile['attempts'])==1 and compile['attempts'][0]['status']=='success' and compile['attempts'][0]['exit_code']==0
 assert '** TEST BUILD SUCCEEDED **' in Path('/private/tmp/pr890-a03-compile-a2268fe0.log').read_text()
 inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True,timeout=20))
 matches=[d for group in inventory['devices'].values() for d in group if d['udid']==UID]
 assert len(matches)==1 and matches[0]['name']==NAME and matches[0]['state']=='Booted' and matches[0]['isAvailable'] is True
 proxy_record=ROOT/'.codex-checks/pipeline'/('check-'+hashlib.sha256(PROXY.encode()).hexdigest()[:24]+'.json')
 entry=ROOT/'.codex-checks/a03/ipad-calc-approved-extra-a2268fe0-entry.log'
 receipt=ROOT/'.xcodebuild/a03-ipad-calc-approved-extra-a2268fe0.log.result.json'
 assert not MARKER.exists() and not proxy_record.exists() and not entry.exists() and not receipt.exists()
 proof=dict(authorization='모두 1회 추가 허용 알아서 처리하고 머지까지 완료',approvalGroup=GROUP,originalPipelineID=ORIGINAL,proxyRecordID=PROXY,selector=SELECTOR,revision=REV,device=UID,approvedExtra=1,consumed=1,remaining=0,status='running',started=time.time(),historyPins=PINS['history'],infraProof=str(INFRA),compilePins=PINS['proofs'])
 with LEDGER.with_name('user-approval-ledger.lock').open('a+b') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  ledger=load(LEDGER); frozen=json.loads(json.dumps(ledger)); group=ledger[GROUP]; slot=group['perCase']['A03extraCalc']
  logical=ORIGINAL+'::'+SELECTOR
  assert logical not in group.get('consumedLogicalCases',{})
  assert ledger['A03extraCalc']=='explicit_user_HOLD' and group['A03PriorHoldSuperseded']=='Latest 모두1회추가 permission authorizes one necessary A03 calculation check despite older HOLD; older ledger text retained as history'
  assert group['authorization']==proof['authorization'] and (slot['approvedExtra'],slot['consumed'],slot['remaining'])==(1,0,1)
  assert not MARKER.exists() and unchanged() and history_unchanged() and all(sha(Path(p))==h for p,h in PINS['proofs'].items())
  slot.update(consumed=1,remaining=0,marker=str(MARKER),proxyRecordID=PROXY,device=UID,executionSource=REV,executionSelector=SELECTOR,originalLogicalID=ORIGINAL)
  group.setdefault('consumedLogicalCases',{})[logical]=str(MARKER)
  assert all(ledger[k]==v for k,v in frozen.items() if k!=GROUP)
  assert all(group[k]==v for k,v in frozen[GROUP].items() if k not in ('perCase','consumedLogicalCases'))
  assert all(group['perCase'][k]==v for k,v in frozen[GROUP]['perCase'].items() if k!='A03extraCalc')
  assert all(group['consumedLogicalCases'][k]==v for k,v in frozen[GROUP].get('consumedLogicalCases',{}).items())
  durable_replace(LEDGER,ledger)
  with MARKER.open('x') as f: json.dump(proof,f,ensure_ascii=False,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
  syncdir(MARKER.parent)
 command=[sys.executable,'-B','scripts/codex-pipeline.py','run',PROXY,'--context','A03-a2268fe0-approved-extra-original-history-preserved','--scope','One approved additional execution of exact original calculation selector; no retry','--timeout','1250','--',sys.executable,'-B','scripts/lib/simulator-test-lock.py',str(ROOT),'--','scripts/test-ui.sh','--no-regen','--stream-log','--test-plan','DUNEUITests-DesignCapture','--simulator-udid',UID,'--only-testing',SELECTOR,'--log-file','.xcodebuild/a03-ipad-calc-approved-extra-a2268fe0.log']
 env=dict(os.environ,DUNE_SIM_TEST_LOCK_SCOPE='worktree',DUNE_SIM_TEST_LOCK_WAIT_SECONDS='0',DUNE_UI_TEST_WALL_TIMEOUT='1200')
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
