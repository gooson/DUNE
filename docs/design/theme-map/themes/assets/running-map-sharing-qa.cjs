const fs = require('fs');
const path = require('path');
const { chromium } = require('/Users/shanks/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const crypto = require('crypto');
const repo = path.resolve(__dirname, '../../../../..');
const fragment = path.join(__dirname, 'running-map-sharing-fragment.html');
const html = path.resolve(__dirname, '../dune-running-map-sharing.html');
const output = __dirname;
let ownedBrowser;
(async () => {
  const browser = ownedBrowser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
  const page = await browser.newPage({viewport:{width:736,height:1100},deviceScaleFactor:1});
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto('file://'+html);
  const frame = page.frameLocator('iframe');
  await frame.locator('#dune-run-study .poster').first().waitFor();
  await page.waitForTimeout(400);
  const body = page.frames().find(f=>f!==page.mainFrame());
  const rows=[];
  const names=['atlas','ribbon','signature','journey','passport'];
  const selectVariant = async key => body.evaluate(key=>{
    document.querySelectorAll('[data-variant]').forEach(s=>s.hidden=s.querySelector('[data-design]')?.dataset.design!==key);
    document.dispatchEvent(new Event('resize'));
  },key);
  for(const width of [320,736,1024]) {
    await page.setViewportSize({width,height:1200});
    for(const appearance of ['light','dark']) {
      await page.emulateMedia({colorScheme:appearance});
      for(const key of names) {
        await selectVariant(key);
        const shell=frame.locator(`.run-shell[data-design="${key}"]`);
        for(const record of ['outdoor','indoor','missing']) {
          await shell.evaluate((el,value)=>{const s=el.querySelector('select[data-action=record]');s.value=value;s.dispatchEvent(new Event('change',{bubbles:true}));},record);
          for(const view of ['share','detail']) {
            await shell.evaluate((el,value)=>el.querySelector(`button[data-view=${value}]`).click(),view);
            const measurement=await shell.evaluate(el=>{
              const root=el.getBoundingClientRect();
              const poster=el.querySelector('.poster,.detail');
              const p=poster.getBoundingClientRect();
              const clipped=[...el.querySelectorAll('h2,h3,p,strong,button,select,label,.metric,.topline,.format-control,.stamps')].filter(x=>{const b=x.getBoundingClientRect();return b.width>0&&(b.left<root.left-2||b.right>root.right+2);}).map(x=>x.className||x.tagName);
              return {rootWidth:root.width,contentWidth:p.width,overflow:el.scrollWidth>el.clientWidth+2,clipped,routePaths:el.querySelectorAll('.route-line').length,bodyWidth:document.documentElement.scrollWidth};
            });
            rows.push({width,appearance,key,record,view,...measurement});
            if(width===736 && record==='outdoor' && view==='share')await shell.locator('.poster').screenshot({path:path.join(output,`running-map-${key}-${appearance}.png`)});
          }
        }
      }
    }
  }
  await page.setViewportSize({width:320,height:1200});
  for(const key of names) {
    await selectVariant(key);
    const shell=frame.locator(`.run-shell[data-design="${key}"]`);
    await shell.locator('select[data-action="record"]').selectOption('outdoor');
    await shell.locator('button[data-view="share"]').first().click();
    await shell.locator('[data-option="large"]').check();
    const m=await shell.evaluate(el=>({overflow:el.scrollWidth>el.clientWidth+2,clipped:[...el.querySelectorAll('h2,h3,p,strong,button,label')].filter(x=>{const b=x.getBoundingClientRect(),r=el.getBoundingClientRect();return b.width>0&&(b.left<r.left-2||b.right>r.right+2);}).map(x=>x.className||x.tagName)}));
    rows.push({width:320,key,large:true,...m});
    await shell.locator('[data-option="large"]').uncheck();
  }
  fs.writeFileSync(path.join(output,'running-map-layout-checks.json'),JSON.stringify({rows,errors},null,2)+'\n');
  console.log('Layout checks complete: '+rows.length);
  await page.setViewportSize({width:736,height:1100});
  await selectVariant('atlas');
  const atlas=frame.locator('.run-shell.atlas');
  await atlas.locator('select[data-action="record"]').selectOption('outdoor');
  const firstPath=await atlas.locator('.poster .route-line').getAttribute('d');
  await atlas.locator('[data-option="privacy"]').uncheck();
  const fullPath=await atlas.locator('.poster .route-line').getAttribute('d');
  if(firstPath===fullPath)errors.push('Privacy did not change public route geometry');
  await atlas.locator('[data-option="privacy"]').check();
  const h1=await atlas.locator('.poster').evaluate(e=>e.getBoundingClientRect().height);
  await atlas.locator('[data-ratio="story"]').click();
  const h2=await atlas.locator('.poster').evaluate(e=>e.getBoundingClientRect().height);
  if(h2<=h1)errors.push('Story format did not increase card height');
  await atlas.locator('[data-ratio="feed"]').click();
  if(await atlas.locator('.poster').count()!==1)errors.push('Share preview missing');
  const failures=rows.filter(r=>r.overflow||r.clipped.length);
  const report={sourceSHA256:crypto.createHash('sha256').update(fs.readFileSync(fragment)).digest('hex'),scope:'Browser concept only. Not native app screenshots or GPS/HealthKit verification.',geometrySource:'running-map-provenance.json',checks:rows.length,failures,errors,interactions:['record state','detail/share','geometry trimming','format height','large text','share preview visible'],captures:names.flatMap(n=>['light','dark'].map(a=>`running-map-${n}-${a}.png`)),rows};
  fs.writeFileSync(path.join(output,'running-map-sharing-qa.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({checks:rows.length,failures,errors}));
  await browser.close();
  if(failures.length||errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(async()=>{if(ownedBrowser)await ownedBrowser.close();});
