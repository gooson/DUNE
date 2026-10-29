const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('/Users/shanks/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const folder=__dirname;
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:736,height:1200}}),errors=[],rows=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto('file://'+path.resolve(folder,'../dune-running-map-sharing.html'));
  const frame=page.frameLocator('iframe');await frame.locator('.run-shell.atlas .poster').waitFor();
  const inner=page.frames().find(f=>f!==page.mainFrame());
  const names=['atlas','ribbon','signature','journey','passport'];
  const show=key=>inner.evaluate(key=>document.querySelectorAll('[data-variant]').forEach(s=>s.hidden=s.querySelector('[data-design]').dataset.design!==key),key);
  for(const width of [320,736])for(const appearance of ['light','dark']){
   await page.setViewportSize({width,height:1200});await page.emulateMedia({colorScheme:appearance});
   for(const key of names){
    await show(key);const shell=frame.locator(`.run-shell.${key}`);
    await shell.evaluate(el=>{const s=el.querySelector('[data-action=record]');s.value='indoor';s.dispatchEvent(new Event('change',{bubbles:true}));});
    for(const view of ['share','detail']){
     await shell.evaluate((el,v)=>el.querySelector(`button[data-view=${v}]`).click(),view);
     const result=await shell.evaluate(el=>{const r=el.getBoundingClientRect();return {overflow:el.scrollWidth>el.clientWidth+2,clipped:[...el.querySelectorAll('strong,h3,p,label,button,select')].filter(x=>{const b=x.getBoundingClientRect();return b.width>0&&(b.left<r.left-2||b.right>r.right+2)}).map(x=>x.textContent),venueMaps:el.querySelectorAll('.venue-block').length};});
     rows.push({width,appearance,key,view,...result});
     if(result.venueMaps!==1)errors.push(`${key}/${view}: expected one actual venue map`);
     if(width===736&&appearance==='light'&&view==='share')await shell.locator('.poster').screenshot({path:path.join(folder,`running-map-${key}-indoor-place.png`)});
    }
   }
  }
  for(const key of names){
   await show(key);const shell=frame.locator(`.run-shell.${key}`);
   await shell.evaluate(el=>el.querySelector('button[data-view=share]').click());
   await shell.locator('[data-option="shareVenue"]').uncheck();
   const hidden=await shell.locator('.poster').evaluate(el=>el.querySelectorAll('.venue-block').length===0&&!el.textContent.includes('성동구민종합체육센터')&&!el.textContent.includes('서울숲복합문화센터'));
   if(!hidden)errors.push(key+': shared venue was not removed');
   await shell.locator('[data-option="shareVenue"]').check();
   await shell.locator('[data-action="venue"]').selectOption('culture');
   if(!await shell.locator('.poster').innerText().then(t=>t.includes('서울숲복합문화센터')))errors.push(key+': venue selection did not update');
   await shell.locator('[data-action="venue"]').selectOption('unset');
   if(!await shell.locator('.poster').innerText().then(t=>t.includes('운동 장소를 선택해 주세요')))errors.push(key+': unknown venue state missing');
   await shell.locator('[data-action="venue"]').selectOption('center');
  }
  await page.setViewportSize({width:320,height:1300});
  for(const key of names){
   await show(key);const shell=frame.locator(`.run-shell.${key}`);await shell.evaluate(el=>{const e=el.querySelector('[data-option=large]');e.checked=true;e.dispatchEvent(new Event('change',{bubbles:true}));});
   const result=await shell.evaluate(el=>{const r=el.getBoundingClientRect();return {overflow:el.scrollWidth>el.clientWidth+2,clipped:[...el.querySelectorAll('strong,h3,p,label,select')].filter(x=>{const b=x.getBoundingClientRect();return b.width>0&&(b.left<r.left-2||b.right>r.right+2)}).map(x=>x.textContent)};});
   rows.push({width:320,key,large:true,...result});await shell.evaluate(el=>{const e=el.querySelector('[data-option=large]');e.checked=false;e.dispatchEvent(new Event('change',{bubbles:true}));});
  }
  const failures=rows.filter(r=>r.overflow||r.clipped.length);
  const report={sourceSHA256:crypto.createHash('sha256').update(fs.readFileSync(path.join(folder,'running-map-sharing-fragment.html'))).digest('hex'),scope:'Indoor place-map concept. Two sourced example facilities, no device location or real workout accessed.',checks:rows.length,rows,failures,errors,interactions:['two venue selections','unassigned venue','remove venue geometry and name from share card','private workout detail retains venue','large text'],previousReport:'running-map-sharing-qa.json (before indoor place-map extension; source hashes differ)'};
  fs.writeFileSync(path.join(folder,'running-map-indoor-qa.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({checks:rows.length,failures,errors}));if(failures.length||errors.length)process.exitCode=1;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
