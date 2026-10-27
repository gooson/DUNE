// Browser-only proposal checks. Run with bundled Node and Playwright.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const os = require('os');
const { execFileSync } = require('child_process');
const assert = require('assert/strict');
const runtime = process.env.CODEX_NODE_MODULES || '/Users/shanks/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const { chromium } = require(path.join(runtime, 'playwright'));
const assets = __dirname;
const wrapper = path.join(assets, '../dune-wellness-redesign.html');
const fragment = path.join(assets, 'wellness-redesign-fragment.html');
const direct = path.join(os.tmpdir(), 'dune-wellness-qa-direct.html');
execFileSync('python3', ['-c', 'from pathlib import Path; import html,re,sys; s=Path(sys.argv[1]).read_text(); Path(sys.argv[2]).write_text(html.unescape(re.search(r\'data-srcdoc="(.*?)"\',s,re.S).group(1)).replace("__CODEX_VISUALIZATION_WIDGET_STATE__", "{}"))', wrapper, direct]);
const sourceSHA256 = crypto.createHash('sha256').update(fs.readFileSync(fragment)).digest('hex');
const environmentOnly = process.argv.includes('--environment-only');
const captureOnly = process.argv.includes('--capture-only');
const previous = environmentOnly || captureOnly ? JSON.parse(fs.readFileSync(path.join(assets, 'wellness-redesign-qa.json'))) : null;
if (previous) assert.equal(previous.sourceSHA256, sourceSHA256, 'Reuse requires identical proposal source');
const report = { date: '2026-10-27', kind: 'browser-prototype-only', sourceSHA256, browser: 'Installed Google Chrome via Playwright', nativeValidation: false, layouts: previous?.layouts || [], states: previous?.states || [], interactions: previous?.interactions || [], screenshots: captureOnly ? [] : previous?.screenshots || [], errors: [] };
let browser;
(async () => {
  browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  const page = await browser.newPage({ viewport: { width: 1120, height: 1000 }, deviceScaleFactor: 1 });
  page.on('pageerror', error => report.errors.push(error.message));
  await page.goto(`file://${direct}`);
  await page.waitForFunction(() => document.querySelector('#wellness-redesign')?.updatePreview);
  if (environmentOnly) {
    assert.equal(await page.locator('.phone').count(), 2);
    await page.goto(`file://${wrapper}`);
    await page.waitForFunction(() => !!document.querySelector('iframe')?.srcdoc);
    const frame = page.frames()[1];
    await frame.waitForFunction(() => !!document.querySelector('#wellness-redesign')?.updatePreview);
    assert.equal(await frame.locator('.phone').count(), 2);
    assert.equal(await frame.locator('[data-variant]:visible').count(), 1);
    assert.deepEqual(report.errors, []);
    report.result = 'passed';
    report.remediation = { scope: 'Unchanged source: reused 80 layouts, 20 states, 52 interactions and 12 screenshots; only capture-environment initialization rechecked.', initialCapture: 'The sandboxed iframe clipped the first long screenshot; it was discarded. Captures use the direct inner document.', environmentFailure: previous.errors, correction: 'Direct-document harness now supplies the same empty globals object as the standalone shell instead of an unresolved placeholder or null. Direct document and original sandboxed standalone load without page errors.' };
    console.log(JSON.stringify({ result: report.result, scope: 'environment-only', reusedSourceSHA256: sourceSHA256 }));
    return;
  }
  const select = async (design, patch = {}) => {
    await page.evaluate(({ design, patch }) => {
      const root = document.querySelector('#wellness-redesign');
      root.updatePreview(patch);
      root.querySelectorAll('[data-variant]').forEach(section => { section.hidden = section.querySelector('.phone').dataset.design !== design; });
    }, { design, patch });
    return page.locator(`.phone[data-design="${design}"]`);
  };
  const measure = async phone => phone.evaluate(el => {
    const bounds = el.getBoundingClientRect();
    const overflow = [...el.querySelectorAll('*')].filter(e => {
      const r = e.getBoundingClientRect();
      return r.width && r.height && (r.right > bounds.right + 1 || r.left < bounds.left - 1);
    }).map(e => `${e.tagName}.${e.className?.baseVal ?? e.className}: ${e.textContent.trim().slice(0, 30)}`);
    return { width: bounds.width, overflow: overflow.slice(0, 12), ring: el.querySelector('.ring')?.getBoundingClientRect().toJSON(), external: !!el.querySelector('.external-score') && getComputedStyle(el.querySelector('.external-score')).display !== 'none', cards: [...el.querySelectorAll('[data-card]')].map(e => e.dataset.card) };
  });
  if (!captureOnly) {
  for (const design of ['flow', 'compact']) for (const width of [320, 402, 466, 951, 1032]) for (const text of [100, 125, 160, 200]) for (const appearance of ['light', 'dark']) {
    const phone = await select(design, { width, text, appearance, data: 'complete', score: 79 });
    const result = await measure(phone);
    assert.equal(result.width, width);
    assert.deepEqual(result.overflow, [], `${design} ${width} ${text} ${appearance}`);
    assert.equal(result.external, text >= 160);
    if (text < 160) { assert.equal(result.ring.width, 104); assert.equal(result.ring.height, 104); }
    assert.deepEqual(result.cards, design === 'flow' ? ['hero', 'sleep', 'prediction', 'vitals', 'body', 'watch', 'posture', 'injury'] : ['hero', 'prediction', 'body', 'vitals', 'watch', 'posture', 'injury']);
    report.layouts.push({ design, width, text, appearance, pass: true });
  }
  for (const design of ['flow', 'compact']) for (const data of ['partial', 'single', 'body-only', 'stale', 'watch-off', 'injury', 'empty', 'access', 'sync', 'loading']) {
    const phone = await select(design, { width: 320, text: 200, appearance: 'dark', data });
    assert.deepEqual((await measure(phone)).overflow, [], `${design} ${data}`);
    const text = await phone.innerText();
    if (['empty', 'access', 'sync', 'loading'].includes(data)) { assert.equal(await phone.locator('.ring').count(), 0); assert.equal(await phone.locator('.sleep-bar').count(), 0); assert.equal(await phone.locator('[aria-label="기록 추가"]').isEnabled(), true); }
    if (data === 'single') { assert.equal(await phone.locator('.sleep-bar:not(.empty)').count(), 1); assert.ok(text.includes('평균은 2일 이상부터')); assert.equal(await phone.locator('.mini-chart').count(), 0); }
    if (data === 'partial') { assert.equal(await phone.locator('.missing .track i').count(), 0); assert.ok(text.includes('일부 기록')); }
    if (data === 'stale') assert.ok(text.includes('3일 전 기록'));
    if (data === 'watch-off') assert.ok(text.includes('모니터링이 꺼져'));
    if (data === 'injury' && design === 'flow') assert.deepEqual((await measure(phone)).cards.slice(0, 5), ['hero', 'sleep', 'prediction', 'injury', 'vitals']);
    report.states.push({ design, data, width: 320, text: 200, pass: true });
  }
  for (const score of [0, 1, 99, 100]) {
    const phone = await select('flow', { width: 402, text: 100, appearance: 'light', data: 'complete', score });
    assert.equal(await phone.locator('.ring strong').innerText(), String(score));
    const arc = phone.locator('.ring circle').nth(1);
    assert.equal(await arc.getAttribute('visibility'), score === 0 ? 'hidden' : null);
    report.interactions.push({ score, pass: true });
  }
  for (const design of ['flow', 'compact']) {
    const phone = await select(design, { width: 402, text: 100, appearance: 'light', data: 'complete', score: 79 });
    const routes = ['wellness', 'sleep', 'prediction', 'body-history', 'body-record', 'posture-history', 'posture-capture', 'posture-live', 'injury-record', 'compare', 'add', 'metric-hrv', 'metric-rhr', 'metric-heart', 'metric-spo2', 'metric-resp', 'metric-temp', 'metric-vo2', 'metric-recovery', 'body-weight', 'body-0', 'body-1', 'body-2'];
    for (const route of routes) {
      const target = phone.locator(`[data-route="${route}"]`).first();
      if (!(await target.isVisible())) await phone.locator('summary').filter({ hasText: '심폐 체력' }).click();
      const box = await target.boundingBox();
      await target.click({ position: { x: Math.max(2, box.width - 5), y: box.height / 2 } });
      assert.equal(await phone.locator('.detail-page').count(), 1, route);
      if (route === 'body-record') { await phone.locator('input').fill('70.2'); await phone.locator('button[type="submit"]').click(); assert.ok((await phone.locator('[data-confirmation]').innerText()).includes('실제 기록은 저장하지')); }
      await phone.locator('[data-back]').click();
      assert.equal(await phone.locator('.detail-page').count(), 0);
      report.interactions.push({ design, route, pass: true });
    }
  }
  for (const [data, route] of [['access', 'health-access'], ['sync', 'sync'], ['injury', 'injury-detail']]) {
    const phone = await select('flow', { data, text: 100 });
    await phone.locator(`[data-route="${route}"]`).click();
    assert.equal(await phone.locator('.detail-page').count(), 1);
    await phone.locator('[data-back]').click();
    report.interactions.push({ data, route, pass: true });
  }
  const single = await select('flow', { data: 'single' });
  await single.locator('[data-route="sleep"]').click();
  await single.locator('summary').click();
  assert.equal(await single.locator('details p').count(), 1);
  report.interactions.push({ data: 'single', route: 'sleep-detail-one-sample', pass: true });
  for (const design of ['flow', 'compact']) for (const bodyComparison of [true, false]) {
    const phone = await select(design, { data: 'complete', width: 320, text: 200, bodyComparison });
    const body = phone.locator('[data-card="body"]');
    assert.equal(await body.locator('.body-panel').count(), 4);
    assert.equal(await body.locator('.delta').count(), bodyComparison ? 4 : 0);
    assert.equal(await body.locator('.no-comparison').count(), bodyComparison ? 0 : 4);
    assert.equal(await body.locator('.mini-chart').count(), 2, 'Only weight and fat have a valid trend fixture');
    assert.deepEqual((await measure(phone)).overflow, []);
    if (bodyComparison) {
      assert.ok((await body.innerText()).includes('10.20 → 10.27'));
      assert.ok((await body.locator('[data-body="fat"] .delta').innerText()).includes('−0.4 %p'));
      assert.ok((await body.innerText()).includes('비교 기록이 있는 경우 · 예시'));
    }
    for (const route of ['body-weight', 'body-0', 'body-1', 'body-2']) {
      await phone.locator(`[data-route="${route}"]`).click();
      const detail = phone.locator('.detail-page');
      assert.equal(await detail.locator('.delta').count(), bodyComparison ? 1 : 0);
      await phone.locator('[data-back]').click();
    }
    report.interactions.push({ design, bodyComparison, scope: 'four body values, comparison dates/units, missing comparison, retained actual trends and four matching destinations', pass: true });
  }
  for (const data of ['complete', 'body-only']) {
    const phone = await select('flow', { data, width: 402, text: 100 });
    const posture = phone.locator('[data-card="posture"]');
    assert.ok((await posture.locator('figure').getAttribute('aria-label')).includes('실제 자세 평가 결과가 아닙니다'));
    assert.equal(await posture.locator('.posture-meter').count(), data === 'complete' ? 1 : 0);
    assert.equal(await posture.locator('.assessment-actions button').count(), 2);
    report.interactions.push({ data, scope: 'capture guide separated from assessment, no score without assessment', pass: true });
  }
  }
  for (const design of ['flow', 'compact']) for (const appearance of ['light', 'dark']) {
    const phone = await select(design, { width: 402, text: 100, appearance, data: 'complete', score: 79, bodyComparison: true });
    const name = `wellness-${design}-${appearance}`;
    await phone.screenshot({ path: path.join(assets, `${name}-full.png`) });
    const rect = await phone.evaluate(el => { const rect = el.getBoundingClientRect(); return { x: rect.left + scrollX, y: rect.top + scrollY, width: rect.width, height: rect.height }; });
    await page.screenshot({ path: path.join(assets, `${name}.png`), clip: { x: rect.x, y: rect.y, width: rect.width, height: 1200 } });
    report.screenshots.push(`${name}.png`, `${name}-full.png`);
    if (design === 'flow') for (const card of ['hero', 'vitals', 'body', 'posture']) {
      const name = `wellness-${card}-${appearance}.png`;
      await phone.locator(`[data-card="${card}"]`).screenshot({ path: path.join(assets, name) });
      report.screenshots.push(name);
    }
  }
  for (const [name, patch] of [['large', { width: 320, text: 200, appearance: 'dark' }], ['wide', { width: 1032, text: 100, appearance: 'light' }], ['injury', { width: 402, text: 100, data: 'injury' }], ['empty', { width: 402, text: 100, data: 'empty' }]]) {
    const phone = await select('flow', { data: 'complete', appearance: 'light', ...patch });
    await phone.screenshot({ path: path.join(assets, `wellness-flow-${name}.png`) });
    report.screenshots.push(`wellness-flow-${name}.png`);
  }
  assert.deepEqual(report.errors, []);
  report.result = 'passed';
  if (captureOnly) report.remediation = { scope: 'Only screenshot capture rerun. Reused successful layout/state/interaction checks after exact source hash match.', failure: previous.failure?.split('\n')[0], correction: 'Top-of-screen clip now uses document coordinates, accounting for scrolling performed by element screenshots.' };
  console.log(JSON.stringify({ result: report.result, layouts: report.layouts.length, states: report.states.length, interactions: report.interactions.length, screenshots: report.screenshots.length }));
})().catch(error => { report.result = 'failed'; report.failure = error.stack; console.error(error.message); process.exitCode = 1; }).finally(async () => { fs.writeFileSync(path.join(assets, 'wellness-redesign-qa.json'), JSON.stringify(report, null, 2) + '\n'); if (browser) await browser.close(); });
