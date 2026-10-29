const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('/Users/shanks/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
const b=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
try{
 const p=await b.newPage({viewport:{width:320,height:1300}}),errors=[],rows=[];p.on('pageerror',e=>errors.push(e.message));
 await p.goto('file://'+path.resolve(__dirname,'../dune-running-map-sharing.html'));const frame=p.frameLocator('iframe');await frame.locator('.run-shell.atlas .poster').waitFor();
 const inner=p.frames().find(f=>f!==p.mainFrame()),designs=['atlas','ribbon','signature','journey','passport'];
 const show=k=>inner.evaluate(k=>document.querySelectorAll('[data-variant]').forEach(e=>e.hidden=e.querySelector('[data-design]').dataset.design!==k),k);
 const list=await frame.locator('.run-shell.atlas [data-action=activity] option').evaluateAll(es=>es.map(e=>e.value));
 for(const key of designs){await show(key);const shell=frame.locator('.run-shell.'+key);
  for(const activity of list){
   await shell.evaluate((el,a)=>{const s=el.querySelector('[data-action=activity]');s.value=a;s.dispatchEvent(new Event('change',{bubbles:true}));},activity);
   const result=await shell.evaluate(el=>{const r=el.getBoundingClientRect(),card=el.querySelector('.poster');return {overflow:el.scrollWidth>el.clientWidth+2,clipped:[...el.querySelectorAll('h3,strong,p,label,select')].filter(x=>{const q=x.getBoundingClientRect();return q.width>0&&(q.left<r.left-2||q.right>r.right+2)}).map(x=>x.textContent),venueMaps:card.querySelectorAll('.venue-block').length,routeLines:card.querySelectorAll('.route-line').length,text:card.innerText};});
   if(result.venueMaps!==1)errors.push(`${key}/${activity}: place map absent`);
   if(activity!=='running'&&result.routeLines)errors.push(`${key}/${activity}: indoor route fabricated`);
   if(['elliptical','stairs','stepper','jumpRope','hiit','other'].includes(activity)&&(/6\.28|FIRST 5K|\/km/.test(result.text)))errors.push(`${key}/${activity}: running metrics leaked`);
   delete result.text;rows.push({width:320,key,activity,view:'share',...result});
   if(key==='atlas'){
    await shell.evaluate(el=>el.querySelector('[data-view=detail]').click());
    if(await shell.locator('.detail .venue-block').count()!==1)errors.push(`${activity}: detail place absent`);
    await shell.evaluate(el=>el.querySelector('[data-view=share]').click());
   }
  }
 }
 await p.setViewportSize({width:736,height:1200});await show('atlas');const atlas=frame.locator('.run-shell.atlas');
 for(const activity of ['cycling','elliptical','stairs','rowing']){await atlas.locator('[data-action=activity]').selectOption(activity);await atlas.locator('.poster').screenshot({path:path.join(__dirname,`cardio-${activity}-place.png`)});}
 await atlas.locator('[data-option=shareVenue]').uncheck();if(await atlas.locator('.poster .venue-block').count())errors.push('Cardio place privacy did not remove map');
 const failures=rows.filter(r=>r.overflow||r.clipped.length),report={sourceSHA256:crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'running-map-sharing-fragment.html'))).digest('hex'),scope:'Concept only. All supported demo activities, place sharing independent of metric unit. No native app or sensors tested.',checks:rows.length,rows,failures,errors,extraChecks:['11 Atlas detail states','activity picker pointer selection','place privacy']};
 fs.writeFileSync(path.join(__dirname,'running-map-cardio-qa.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({checks:rows.length,failures,errors}));if(failures.length||errors.length)process.exitCode=1;
}finally{await b.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
