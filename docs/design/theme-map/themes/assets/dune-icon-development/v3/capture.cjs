const {chromium}=require(process.env.DUNE_CAPTURE_PLAYWRIGHT || 'playwright-core');
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const assert=require('assert');
const root=path.resolve('docs/design/theme-map/themes');
const v3=path.join(root,'assets/dune-icon-development/v3');
const output=path.join(v3,'captures'),boards=path.join(v3,'boards');
fs.mkdirSync(path.join(output,'homes'),{recursive:true});fs.mkdirSync(boards,{recursive:true});
const manifest=JSON.parse(fs.readFileSync(path.join(v3,'prompts.json'),'utf8'));
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const boardCSS=`*{box-sizing:border-box}body{margin:0;padding:36px;background:#1c1916;color:#f4ecdf;font-family:-apple-system,BlinkMacSystemFont,sans-serif}.eyebrow{font-size:14px;color:#d7b37d;letter-spacing:.14em}h1{font-size:34px;letter-spacing:-1.1px;margin:12px 0}header p{font-size:17px;color:#b8ac9c;margin:10px 0 28px;line-height:1.55}main{display:grid;grid-template-columns:1fr 1fr;gap:26px 24px}article{min-width:0}.art{width:100%;display:block;border-radius:23%}h2{font-size:20px;font-weight:550;margin:12px 0 5px}b{color:#dbb175;font-weight:550;margin-right:7px}.theme{font-size:13px;color:#b7ac9d;margin:0;line-height:1.4}.micro{display:flex;align-items:center;gap:12px;margin-top:10px}.micro img{width:40px;height:40px;border-radius:23%}.micro span{font-size:12px;color:#a99d8b}footer{font-size:13px;color:#a99a84;margin-top:28px;line-height:1.5}.home-art{width:100%;display:block}.home h2{margin-top:7px}`;
function doc(title,subtitle,cards,extra=''){return `<!doctype html><html lang="ko"><meta charset="utf-8"><title>${escape(title)}</title><style>${boardCSS}${extra}</style><header><div class="eyebrow">DUNE / ICON DEVELOPMENT / V3</div><h1>${escape(title)}</h1><p>${escape(subtitle)}</p></header><main>${cards}</main><footer>2026.11.03 · 50개 별도 생성 시안 · 기존 사구·생체 리듬·회복력 유지<br>CSS 마스크·HTML 홈 화면 목업 · 실제 iPhone 설치 캡처·시스템 Liquid Glass 검증 아님</footer></html>`;}
for(const g of manifest.groups){
 const concepts=manifest.concepts.filter(c=>c.group===g.id);
 const cards=concepts.map(c=>`<article><img class="art" src="../${c.id}.png"><h2><b>${c.number}</b>${escape(c.name)}</h2><p class="theme">${escape(c.themeName)}</p><div class="micro"><img src="../${c.id}.png"><span>40px · ${escape(c.desc)}</span></div></article>`).join('');
 fs.writeFileSync(path.join(boards,'group-'+g.id+'-icons.html'),doc(g.id.toUpperCase()+' · '+g.name+' / '+concepts[0].number+'–'+concepts.at(-1).number,g.desc,cards));
 const homeCards=concepts.map(c=>`<article class="home"><img class="home-art" src="../captures/homes/${c.id}.png"><h2><b>${c.number}</b>${escape(c.name)}</h2><p class="theme">${escape(c.themeName)}</p></article>`).join('');
 fs.writeFileSync(path.join(boards,'group-'+g.id+'-homes.html'),doc(g.id.toUpperCase()+' · 홈 화면 비교 / '+g.name,'DUNE은 세 번째 줄 첫 번째 · 같은 배경·같은 크기',homeCards));
}
const allCards=manifest.concepts.map(c=>`<article><img class="art" src="../${c.id}.png"><h2><b>${c.number}</b>${escape(c.name)}</h2><p class="theme">${escape(c.themeName)}</p></article>`).join('');
fs.writeFileSync(path.join(boards,'all-50.html'),doc('50개의 시선, 하나의 리듬.','선 굵기 · 비율과 실루엣 · 테마 키컬러 · 연결과 여백 · 레이어와 재질',allCards,'main{grid-template-columns:repeat(5,minmax(0,1fr));gap:28px}h2{font-size:21px}.theme{font-size:15px}'));
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,timeout:30000,args:['--disable-gpu','--run-all-compositor-stages-before-draw']});
 const deadline=setTimeout(()=>{browser.close();process.exitCode=1;},240000);
 const results={date:'2026-11-03',method:'isolated headless Chrome; local HTML and unmodified generated PNGs',nativeDeviceCapture:false,browserErrors:[],concepts:[],checks:{},captures:[]};
 try{
 const context=await browser.newContext({viewport:{width:1100,height:1100},deviceScaleFactor:1});
 const page=await context.newPage();page.setDefaultTimeout(15000);page.on('pageerror',e=>results.browserErrors.push(e.message));
 await page.goto('file://'+path.join(root,'dune-icon-development.html'));
 async function ready(p){await p.evaluate(async()=>{document.querySelectorAll('img').forEach(i=>i.loading='eager');await Promise.race([Promise.all([...document.images].map(i=>i.decode().catch(()=>{}))),new Promise(r=>setTimeout(r,5000))]);});}
 await ready(page);
 assert.equal(await page.locator('[data-tab="v3"]').getAttribute('aria-pressed'),'true');
 for(const c of manifest.concepts){
  await page.locator('#v3-group').selectOption(c.group);
  assert.equal(await page.locator('.choice').count(),10);
  await page.locator(`[data-id="${c.id}"]`).click();
  await page.locator('.selected-home').evaluate(i=>i.decode());
  assert((await page.locator('.selected-home').getAttribute('src')).endsWith(c.id+'.png'));
  const filename='homes/'+c.id+'.png';
  await page.locator('#new-device').screenshot({path:path.join(output,filename),timeout:15000});
  results.concepts.push({id:c.id,number:c.number,group:c.group,theme:c.theme,homeCapture:filename,assetSha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(v3,c.id+'.png'))).digest('hex')});
  if(results.concepts.length%10===0)console.log('home captures '+results.concepts.length+'/50');
 }
 await page.locator('#v3-group').selectOption('all');assert.equal(await page.locator('.choice').count(),50);results.checks.all50Filter=true;
 for(const version of ['v1','v2']){await page.locator(`[data-tab="${version}"]`).click();assert.equal(await page.locator('.choice').count(),10);}results.checks.previous20=true;
 await page.locator('[data-tab="v3"]').click();await page.locator('#v3-group').selectOption('a');await page.locator('[data-id="21-a-01"]').click();
 await page.locator('#favorite').click();await page.locator('#note').fill('3차 캡처 검증용 메모');await page.reload();assert.equal(await page.locator('#note').inputValue(),'3차 캡처 검증용 메모');await page.locator('#note').fill('');await page.locator('#favorite').click();results.checks.notesAndFavoritesPersist=true;
 await page.locator('#compare').click();assert(await page.locator('#original-device').isVisible());await page.locator('#compare').click();results.checks.originalCompare=true;
 await page.locator('#wallpaper').selectOption('night');assert.equal(await page.locator('.screen').first().getAttribute('data-wallpaper'),'night');await page.locator('#wallpaper').selectOption('day');
 await page.locator('#icon-size').selectOption('68');assert(await page.locator('.screen').first().evaluate(e=>e.classList.contains('large-icons')));await page.locator('#icon-size').selectOption('60');results.checks.wallpaperAndSize=true;
 await page.locator('[data-tab="refs"]').click();assert.equal(await page.locator('.ref:visible').count(),12);results.checks.references12=true;
 await page.locator('[data-tab="history"]').click();assert(await page.locator('#history').isVisible());results.checks.history=true;
 await page.locator('[data-tab="v3"]').click();await page.locator('#v3-group').selectOption('a');await page.setViewportSize({width:430,height:932});await ready(page);await page.screenshot({path:path.join(output,'dashboard-mobile.png'),fullPage:true,timeout:15000});results.captures.push('dashboard-mobile.png');
 const board=await context.newPage();board.setDefaultTimeout(15000);
 for(const g of manifest.groups){
  for(const kind of ['icons','homes']){
   await board.setViewportSize({width:900,height:1000});await board.goto('file://'+path.join(boards,'group-'+g.id+'-'+kind+'.html'));await ready(board);
   assert.equal(await board.locator('img').evaluateAll(xs=>xs.filter(i=>!i.complete||i.naturalWidth===0).length),0);
   const name='group-'+g.id+'-'+kind+'.png';await board.screenshot({path:path.join(output,name),fullPage:true,timeout:15000});results.captures.push(name);
  }
  console.log('boards '+g.id+' saved');
 }
 await board.setViewportSize({width:2000,height:1200});await board.goto('file://'+path.join(boards,'all-50.html'));await ready(board);await board.screenshot({path:path.join(output,'all-50.png'),fullPage:true,timeout:15000});results.captures.push('all-50.png');
 assert.equal(results.concepts.length,50);assert.equal(new Set(results.concepts.map(c=>c.assetSha256)).size,50);assert.equal(results.browserErrors.length,0);
 fs.writeFileSync(path.join(output,'capture-index.json'),JSON.stringify(results,null,2)+'\n');console.log('PASS: 50 home captures, 5 icon boards, 5 home boards, mobile dashboard, all-50 overview, all checks');
 }finally{clearTimeout(deadline);await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
