// Browser proposal verification only. No Siri, HealthKit, native UI, or model execution.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { pathToFileURL } = require('node:url');
let playwright;
try { playwright = require('playwright'); }
catch {
  playwright = require(path.join(process.env.HOME, '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'));
}
const source = path.resolve(__dirname, '../dune-siri-health-queries.html');
const report = {
  date: '2026-10-30', kind: 'html-design-proposal-only', nativeValidation: false,
  sourceSHA256: crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),
  layouts: [], states: [], interactions: [], screenshots: [], errors: []
};
let browser;
(async () => {
  browser = await playwright.chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1500, height: 1100 }, deviceScaleFactor: 1, reducedMotion: 'reduce' });
  page.on('pageerror', error => report.errors.push(String(error)));
  await page.goto(pathToFileURL(source).href);
  assert.equal(await page.locator('[data-screen]').count(), 14);
  const set = patch => page.evaluate(p => window.siriStudy.set(p), patch);
  const measure = () => page.evaluate(() => ({
    pageOverflow: document.documentElement.scrollWidth > innerWidth + 1,
    phones: [...document.querySelectorAll('.phone')].map(phone => ({
      id: phone.closest('[data-screen]').dataset.screen,
      overflow: phone.scrollWidth > phone.clientWidth + 1,
      targets: [...phone.querySelectorAll('button,summary')].filter(e => e.getBoundingClientRect().height < 44).map(e => e.textContent),
      textOverflow: [...phone.querySelectorAll('p,h3,strong,b,summary,.hero-value,.metric,.set-row,.compare>div')]
        .filter(e => e.getClientRects().length && e.scrollWidth > e.clientWidth + 2).map(e => e.className || e.tagName)
    }))
  }));
  // One pass per condition covers every one of the 14 feature boards.
  for (const width of [320, 402, 466, 951, 1032]) {
    for (const text of [1, 1.6, 2]) {
      for (const theme of ['light', 'dark']) {
        await set({ width, text, theme, variant: 'visual', state: 'normal', group: 'all' });
        const m = await measure();
        assert.equal(m.pageOverflow, false, `page ${width}/${text}/${theme}`);
        for (const phone of m.phones) {
          assert.equal(phone.overflow, false, JSON.stringify({ width, text, theme, ...phone }));
          assert.deepEqual(phone.targets, [], `${phone.id} touch targets`);
          assert.deepEqual(phone.textOverflow, [], JSON.stringify({ width, text, theme, ...phone }));
        }
        report.layouts.push({ width, text, theme, screens: m.phones.length, passed: true });
      }
    }
  }
  await set({ variant: 'basic', width: 320, text: 2, theme: 'dark' });
  assert.ok((await measure()).phones.every(x => !x.overflow && !x.textOverflow.length));
  report.layouts.push({ variant: 'basic', width: 320, text: 2, theme: 'dark', screens: 14, passed: true });
  for (const state of ['loading', 'empty', 'locked', 'unavailable', 'offline', 'quota', 'cancelled']) {
    await set({ state, width: 320, text: 2, variant: 'visual', theme: 'dark' });
    const m = await measure();
    assert.ok(m.phones.every(x => !x.overflow && !x.textOverflow.length));
    if (['loading', 'empty', 'locked', 'cancelled'].includes(state)) {
      assert.equal(await page.locator('.hero-value,.metric,.memo-result,.score-ring').count(), 0, state);
      assert.equal(await page.locator('.watch').count(), 0, `${state} watch privacy`);
    } else {
      for (const id of ['SQ10', 'SQ12', 'SQ14']) assert.equal(await page.locator(`#${id} .answer`).count(), 0);
      assert.ok(await page.locator('#SQ06 .hero-value').count());
    }
    report.states.push({ state, screens: 14, passed: true });
  }
  await set({ state: 'normal', width: 402, text: 1, theme: 'light', group: 'all' });
  // Exercise the actual controls, focus restoration, disclosures, and local routes.
  await page.locator('[data-setting=variant] [data-value=basic]').click();
  assert.equal(await page.locator('body.basic').count(), 1);
  await page.locator('[data-setting=variant] [data-value=visual]').click();
  await page.locator('[data-setting=theme] [data-value=dark]').click();
  assert.equal(await page.locator('body.dark').count(), 1);
  await page.locator('#group').selectOption('body');
  assert.equal(await page.locator('[data-screen]').count(), 2);
  await page.locator('#width').selectOption('951');
  await page.locator('#text').selectOption('2');
  assert.equal((await page.evaluate(() => window.siriStudy.get())).width, 951);
  await page.locator('#state').selectOption('locked');
  assert.equal(await page.locator('.hero-value').count(), 0);
  report.interactions.push('variant/theme/filter/width/text/state controls');
  await set({ state: 'normal', width: 402, text: 1, theme: 'light', group: 'all' });
  for (const id of await page.locator('[data-screen]').evaluateAll(es => es.map(e => e.dataset.screen))) {
    await page.locator(`#${id} .source-detail summary`).click();
    assert.equal(await page.locator(`#${id} .source-detail[open]`).count(), 1);
    await page.locator(`#${id} .voice-detail summary`).click();
    assert.equal(await page.locator(`#${id} .voice-detail[open]`).count(), 1);
    await page.locator(`[data-open=${id}]`).click();
    assert.equal(await page.locator('dialog[open]').count(), 1);
    assert.ok((await page.locator('#detail-body').innerText()).length > 20);
    await page.locator('#close-detail').click();
    assert.equal(await page.evaluate(() => document.activeElement.dataset.open), id);
  }
  report.interactions.push('14 source disclosures, 14 voice transcripts, 14 local detail routes and focus returns');
  await page.locator('[data-cancel=SQ14]').click();
  assert.equal(await page.locator('#SQ14 .state-card h3').innerText(), '분석을 취소했어요');
  assert.equal(await page.locator('#SQ14 .answer').count(), 0);
  assert.equal(await page.locator('#SQ03 .set-row').count(), 3);
  report.interactions.push('cancel analysis preserves other records');
  // Guard the wide fallback banner against colliding with the main answer grid.
  await set({ group: 'body', width: 951, text: 1, state: 'offline' });
  const fallbackCollision = await page.evaluate(() => [...document.querySelectorAll('.board')].some(board => {
    const a = board.querySelector('.answer').getBoundingClientRect();
    const b = board.querySelector('.fallback-label').getBoundingClientRect();
    return Math.min(a.right,b.right) - Math.max(a.left,b.left) > 1 && Math.min(a.bottom,b.bottom) - Math.max(a.top,b.top) > 1;
  }));
  assert.equal(fallbackCollision, false);
  report.states.push({ state: 'offline', width: 951, fallbackCollision: false });
  // Save individual screens, a cover sheet, alternate modes, and state examples.
  await page.addStyleTag({ content: '.toolbar{position:relative!important}' });
  await page.setViewportSize({ width: 1500, height: 2400 });
  await set({ state: 'normal', width: 402, text: 1, theme: 'light', group: 'all' });
  for (const id of await page.locator('[data-screen]').evaluateAll(es => es.map(e => e.dataset.screen))) {
    const name = `siri-health-queries-${id.toLowerCase()}-light.png`;
    await page.locator(`#${id}`).screenshot({ path: path.join(__dirname, name) });
    report.screenshots.push({ file: name, screen: id, variant: 'visual', theme: 'light', width: 402, text: 1, kind: 'browser-render' });
  }
  await page.setViewportSize({ width: 1480, height: 1500 });
  await page.evaluate(() => window.scrollTo(0,0));
  await page.screenshot({ path: path.join(__dirname, 'siri-health-queries-overview.png') });
  report.screenshots.push({ file: 'siri-health-queries-overview.png', kind: 'browser-render' });
  for (const fixture of [
    { group: 'body', width: 402, text: 1, theme: 'dark', variant: 'visual', state: 'normal', tag: 'body-dark' },
    { group: 'wellness', width: 320, text: 2, theme: 'light', variant: 'visual', state: 'normal', tag: 'large-text' },
    { group: 'context', width: 951, text: 1, theme: 'dark', variant: 'visual', state: 'normal', tag: 'duo-open' },
    { group: 'all', width: 402, text: 1, theme: 'light', variant: 'basic', state: 'normal', tag: 'v1' },
    { group: 'body', width: 402, text: 1, theme: 'dark', variant: 'visual', state: 'locked', tag: 'locked' }
  ]) {
    const { tag, ...settings } = fixture;
    await set(settings);
    await page.setViewportSize({ width: 1500, height: 2400 });
    const name = `siri-health-queries-${tag}.png`;
    await page.locator('.board').first().screenshot({ path: path.join(__dirname, name) });
    report.screenshots.push({ file: name, ...settings, kind: 'browser-render' });
  }
  // Browser viewport responsiveness is distinct from the proposal device-width selector.
  await page.setViewportSize({ width: 390, height: 844 });
  await set({ group: 'all', width: 402, text: 1, theme: 'light', state: 'normal' });
  assert.equal((await measure()).pageOverflow, false);
  assert.ok((await measure()).phones.every(x => !x.overflow));
  report.layouts.push({ browserViewport: 390, passed: true });
  assert.deepEqual(report.errors, []);
  fs.writeFileSync(path.join(__dirname, 'siri-health-queries-qa.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ passed: true, conditions: report.layouts.length, states: report.states.length, interactions: report.interactions.length, screenshots: report.screenshots.length }));
})().catch(e => { console.error(e); process.exitCode = 1; }).finally(async () => { if (browser) await browser.close(); });
