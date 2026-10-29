const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('/Users/shanks/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:736,height:1300}}),errors=[],rows=[],interactions=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto('file://'+path.resolve(__dirname,'../dune-cardio-atlas-integrated.html'));
  const frame=page.frameLocator('iframe'),root=frame.locator('#cardio-atlas-integrated');await root.locator('.atlas-panel').waitFor();
  const set=async(key,value)=>root.evaluate((el,{key,value})=>{const input=el.querySelector(`[data-setting=${key}]`);input.value=value;input.dispatchEvent(new Event('change',{bubbles:true}));},{key,value});
  const clickPage=async value=>root.evaluate((el,value)=>el.querySelector(`[data-page=${value}]`).click(),value);
  const measure=()=>root.evaluate(el=>{const r=el.getBoundingClientRect();return {overflow:el.scrollWidth>el.clientWidth+2,clipped:[...el.querySelectorAll('h2,h3,strong,p,button,label,select,.main-value')].filter(x=>{const b=x.getBoundingClientRect();return b.width>0&&(b.left<r.left-2||b.right>r.right+2);}).map(x=>x.textContent.trim().slice(0,60))};});
  const settle=async()=>{const height=await root.evaluate(el=>Math.ceil(Math.max(document.body.scrollHeight,document.body.getBoundingClientRect().height)));await page.waitForFunction(h=>document.querySelector('iframe').clientHeight>=h-2,height,{timeout:5000});await root.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));};
  const capture=async name=>{await settle();await root.locator('.atlas-app').screenshot({path:path.join(__dirname,`cardio-integrated-${name}.png`)});};
  for(const width of [320,736,1024])for(const appearance of ['light','dark']){
   await page.setViewportSize({width,height:1300});await page.emulateMedia({colorScheme:appearance});
   for(const environment of ['outdoor','indoor','stationary','missing']){
    await set('environment',environment);await set('activity',environment==='indoor'?'elliptical':environment==='stationary'?'hiit':'running');
    for(const screen of ['detail','share','journey','passport']){
     if(screen==='detail'&&await root.locator('.app-nav [data-page=detail]').count())await clickPage('detail');
     if(screen!=='detail'){
      if(await root.locator('.app-nav [data-page=detail]').count())await clickPage('detail');
      await clickPage(screen);
     }
     rows.push({width,appearance,environment,screen,...await measure()});
     if(width===736&&appearance==='light'&&environment==='outdoor')await capture(screen);
     if(width===736&&appearance==='dark'&&environment==='indoor'&&screen==='detail')await capture('indoor-dark');
    }
   }
  }
  fs.writeFileSync(path.join(__dirname,'cardio-atlas-integrated-layout.json'),JSON.stringify({rows,errors},null,2)+'\n');
  await page.setViewportSize({width:736,height:1800});await page.emulateMedia({colorScheme:'light'});
  await set('environment','outdoor');await set('activity','running');await root.locator('button[data-page=share]').first().click();interactions.push('Detail share button');
  const stylePaths=[];
  for(const style of ['atlas','spectrum','signature']){
   await root.locator(`button[data-style=${style}]`).click();
   if(!await root.locator(`.share-poster.${style}`).count())errors.push('Style missing '+style);
   stylePaths.push({style,backgroundPaths:await root.locator('.share-poster .map-road path').count()});
   await capture('share-'+style);
  }
  interactions.push('Three share styles change actual poster');
  await root.locator('[data-style=atlas]').click();await settle();
  const trimmed=await root.locator('.share-poster .route-line').getAttribute('d');await root.locator('[data-option=trim]').uncheck();
  const full=await root.locator('.share-poster .route-line').getAttribute('d');if(trimmed===full)errors.push('Share route trimming did not change geometry');
  await root.locator('[data-option=trim]').check();interactions.push('Route geometry trimming');
  for(const option of ['includeJourney','includePassport']){
   await root.locator(`[data-option=${option}]`).uncheck();
   const selector=option==='includeJourney'?'.poster-journey':'.poster-achievements';if(await root.locator(selector).count())errors.push('Share inclusion did not update '+option);
   await root.locator(`[data-option=${option}]`).check();
  }
  interactions.push('Journey and Passport inclusion switches');
  await root.locator('[data-option=showPlace]').uncheck();if(await root.locator('.share-poster .map-box').count()||await root.locator('.poster-venue').count())errors.push('Location hidden incompletely');
  await clickPage('detail');if(!await root.locator('.atlas-panel [data-map=route]').count())errors.push('Private map changed after share privacy');interactions.push('Share privacy keeps private map');
  await set('environment','indoor');
  const activities=await root.locator('[data-setting=activity] option').evaluateAll(es=>es.map(e=>e.value));
  for(const activity of activities){await set('activity',activity);rows.push({width:736,environment:'indoor',activity,screen:'detail',...await measure()});if(await root.locator('.route-line').count())errors.push('Indoor route fabricated '+activity);}
  await set('activity','elliptical');await root.locator('[data-venue=unset]').click();if(!await root.locator('.atlas-panel').innerText().then(t=>t.includes('운동 장소를 선택')))errors.push('Missing venue state absent');await root.locator('[data-venue=center]').click();
  await page.setViewportSize({width:320,height:1300});await root.evaluate(el=>{el.dataset.large='true';});
  for(const screen of ['detail','share','journey','passport']){if(await root.locator('.app-nav [data-page=detail]').count())await clickPage('detail');if(screen!=='detail')await clickPage(screen);await root.evaluate(el=>el.dataset.large='true');rows.push({width:320,large:true,environment:'indoor',screen,...await measure()});}
  const failures=rows.filter(r=>r.overflow||r.clipped.length),src=path.join(__dirname,'cardio-atlas-integrated-fragment.html');
  const result={sourceSHA256:crypto.createHash('sha256').update(fs.readFileSync(src)).digest('hex'),scope:'Integrated browser proposal only. No native app, location/sensor recording, HealthKit or image export verification.',checks:rows.length,failures,errors,interactions,stylePaths,rows};
  fs.writeFileSync(path.join(__dirname,'cardio-atlas-integrated-qa.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({checks:rows.length,failures,errors,interactions}));if(failures.length||errors.length)process.exitCode=1;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
