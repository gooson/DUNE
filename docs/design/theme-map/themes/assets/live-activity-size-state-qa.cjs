// Browser proposal QA only; this does not validate ActivityKit or native sizing.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const assets = __dirname;
  const source = path.resolve(assets, '../dune-live-activity-size-state.html');
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 736, height: 3400 }, deviceScaleFactor: 1 });
  const errors = [];
  const failures = [];
  let cases = 0;
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(source).href);
  const frame = page.frameLocator('iframe');
  const root = frame.locator('#dune-live-study');
  await root.waitFor();
  await frame.locator('.viz-carousel-controls').waitFor();

  async function set(config) {
    await root.evaluate((root, config) => {
      const set = (id, value) => {
        const element = root.querySelector(id);
        element.value = String(value);
        element.dispatchEvent(new Event('change', { bubbles: true }));
      };
      if (config.duration !== undefined) set('#ls-duration', config.duration);
      if (config.heart !== undefined) set('#ls-heart', config.heart ? 'yes' : 'no');
      if (config.appearance) set('#ls-appearance', config.appearance);
      if (config.large !== undefined) set('#ls-large', config.large ? 'yes' : 'no');
      if (config.longName !== undefined) set('#ls-name', config.longName ? 'long' : 'short');
      if (config.sport) set('#ls-sport', config.sport);
      if (config.metric) set('#ls-primary', config.metric);
      if (config.data !== undefined) set('#ls-data', config.data);
      if (config.phase) root.querySelector(`[data-phase="${config.phase}"]`).click();
    }, config);
  }

  async function inspect(config) {
    const problems = await root.evaluate((root, config) => {
      const problems = [];
      const stage = root.querySelector('[data-variant]:not([hidden]) .ls-stage');
      if (document.documentElement.scrollWidth > innerWidth + 1) problems.push('horizontal overflow');
      const visible = el => el.getClientRects().length > 0;
      for (const el of stage.querySelectorAll('.ls-slot,.ls-big-time,.ls-primary-heart,.ls-selected-value,.ls-metric')) {
        if (!visible(el)) continue;
        const range = document.createRange();
        range.selectNodeContents(el);
        const rect = range.getBoundingClientRect();
        const box = el.getBoundingClientRect();
        if (rect.width > box.width + 1) problems.push(`content overflow: ${el.className}: ${el.textContent}`);
      }
      for (const el of stage.querySelectorAll('.ls-slot.ls-short')) {
        const box = el.getBoundingClientRect();
        if (Math.abs(box.width - 28) > 0.1 || Math.abs(box.height - 28) > 0.1) problems.push('limited slot is not 28x28 CSS px');
      }
      const liveTiles = stage.querySelector('.ls-grid');
      if (config.phase === 'stale' && liveTiles.querySelector('.ls-big-time,.ls-metrics,.ls-primary-heart,.ls-selected-value')) problems.push('stale values remain');
      if (config.phase === 'ended' && liveTiles.querySelector('.ls-capsule,.ls-minimal,.ls-lock,.ls-island-expanded')) problems.push('ended activity remains');
      if (!config.heart && liveTiles.textContent.includes('142')) problems.push('missing heart rendered as received');
      if (stage.querySelectorAll('.ls-tile').length !== 6) problems.push('six surfaces missing');
      if (stage.querySelector('i[data-lucide]')) problems.push('unrendered icon');
      if(config.direction==='time' && config.phase==='running' && ['distance','weight'].includes(config.metric)) {
        const value=liveTiles.querySelector('.ls-selected-value');
        if(config.data==='missing' && value) problems.push('missing sport metric rendered as received');
        if(config.data!=='missing' && !value) problems.push('received sport metric hidden, including zero');
        if(config.data!=='missing' && value && !value.textContent.includes(config.metric==='distance'?'km':'kg')) problems.push('sport unit missing');
      }
      return problems;
    }, config);
    if (problems.length) failures.push({ ...config, problems });
    cases++;
  }

  for (const width of [320, 393, 736, 1024]) {
    await page.setViewportSize({ width, height: 3400 });
    for (const direction of ['time', 'heart']) {
      const current = await frame.locator('.viz-carousel').getAttribute('data-active-variant');
      if (current !== (direction === 'time' ? '내 선택' : '심박 우선')) await frame.locator('.viz-carousel-next').click();
      for (const phase of ['running', 'paused', 'stale', 'ended']) {
        for (const duration of [45, 1394, 4845, 43320]) {
          for (const heart of [true, false]) {
            const config = { width, direction, phase, duration, heart, large: false, longName: false, sport:'cardio',metric:'time',data:'4.2' };
            await set(config);
            await inspect(config);
          }
        }
      }
      for (const duration of [1394, 43320]) {
        const config = { width, direction, phase: 'running', duration, heart: true, large: true, longName: true };
        await set(config);
        await inspect(config);
      }
    }
  }

  for(const width of [320,736]) {
    await page.setViewportSize({width,height:4000});
    if(await frame.locator('.viz-carousel').getAttribute('data-active-variant')!=='내 선택') await frame.locator('.viz-carousel-next').click();
    for(const sport of ['cardio','strength']) for(const metric of ['time',sport==='cardio'?'distance':'weight','heart']) {
      for(const data of (sport==='cardio'?['4.2','42.2','0','missing']:['60','12.5','0','missing'])) {
        for(const phase of ['running','paused','stale','ended']) {
          const config={width,sport,metric,data,phase,direction:'time',heart:true,duration:1394,large:false,longName:false};
          await set(config);await inspect(config);
        }
      }
    }
    await set({sport:'cardio',metric:'distance'});await set({sport:'strength',metric:'weight'});await set({sport:'cardio'});
    if(await frame.locator('#ls-primary').inputValue()!=='distance') failures.push({width,problems:['cardio preference lost']});
    await set({sport:'strength'});
    if(await frame.locator('#ls-primary').inputValue()!=='weight') failures.push({width,problems:['strength preference lost']});
  }

  const screenshots = [];
  for (const capture of [
    { name: 'time', width: 736, direction: 'time', phase: 'running' },
    { name: 'distance', width:736, direction:'time',phase:'running',sport:'cardio',metric:'distance',data:'4.2' },
    { name: 'weight', width:736, direction:'time',phase:'running',sport:'strength',metric:'weight',data:'60' },
    { name: 'weight-decimal-narrow', width:320, direction:'time',phase:'running',sport:'strength',metric:'weight',data:'12.5',appearance:'dark' },
    { name: 'heart', width: 736, direction: 'heart', phase: 'running' },
    { name: 'paused', width: 736, direction: 'time', phase: 'paused' },
    { name: 'stale', width: 736, direction: 'time', phase: 'stale' },
    { name: 'ended', width: 736, direction: 'time', phase: 'ended' },
    { name: 'narrow-dark-large', width: 320, direction: 'time', phase: 'running', appearance: 'dark', large: true, longName: true, duration: 43320 }
  ]) {
    await page.setViewportSize({ width: capture.width, height: 4000 });
    const current = await frame.locator('.viz-carousel').getAttribute('data-active-variant');
    if (current !== (capture.direction === 'time' ? '내 선택' : '심박 우선')) await frame.locator('.viz-carousel-next').click();
    await set({ appearance: 'light', large: false, longName: false, duration: 1394, heart: true, sport:'cardio',metric:'time',data:'4.2', ...capture });
    const filename = `live-activity-size-state-${capture.name}.png`;
    await root.screenshot({ path: path.join(assets, filename) });
    screenshots.push(filename);
  }
  await browser.close();
  const report = {
    date: '2026-10-30', scope: 'browser proposal only; not native UI or system screenshots',
    browser: 'installed Google Chrome via Playwright; device scale 1',
    source: 'dune-live-activity-size-state.html', widths: [320, 393, 736, 1024],
    cases, failures, errors, screenshots,
    environment: 'Bundled Playwright headless-shell 1234 was absent. Installed Chrome was verified and used.',
    nativeVerification: 'not performed; app source unchanged'
  };
  fs.writeFileSync(path.join(assets, 'live-activity-size-state-qa.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ cases, failures: failures.length, errors, screenshots }));
  if (failures.length) console.log(JSON.stringify(failures.slice(0, 5), null, 2));
  process.exitCode = failures.length || errors.length ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 1; });
