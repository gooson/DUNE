// Bounded visual proposal check; no native ActivityKit certification.
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
let browser;
const report={date:'2026-10-30',scope:'gold variant only, browser proposal',cases:[],screenshots:[],status:'running',native:'not performed'};
function save(){fs.writeFileSync(path.join(__dirname,'live-activity-gold-qa.json'),JSON.stringify(report,null,2)+'\n');}
const deadline=setTimeout(()=>{report.status='deadline';save();console.error('Gold browser QA reached 45-second limit');if(browser)browser.close().catch(()=>{});setTimeout(()=>process.exit(1),3000);},45000);
(async()=>{
  browser=await chromium.launch({channel:'chrome',headless:true,timeout:10000});
  const page=await browser.newPage({viewport:{width:736,height:4000},deviceScaleFactor:1});
  page.setDefaultTimeout(5000);
  page.on('pageerror',e=>{report.error=e.message;});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../dune-live-activity-size-state.html')).href);
  const frame=page.frameLocator('iframe'),root=frame.locator('#dune-live-study');
  await root.waitFor();
  const configs=[
    {name:'cardio',width:736,sport:'cardio',metric:'distance',data:'4.2',phase:'running',capture:true},
    {name:'strength',width:736,sport:'strength',metric:'weight',data:'60',phase:'running',capture:true},
    {name:'decimal-narrow',width:320,sport:'strength',metric:'weight',data:'12.5',phase:'running',capture:true},
    {name:'zero',width:320,sport:'cardio',metric:'distance',data:'0',phase:'running'},
    {name:'missing',width:320,sport:'strength',metric:'weight',data:'missing',phase:'running'},
    {name:'paused',width:736,sport:'strength',metric:'weight',data:'60',phase:'paused'},
    {name:'stale',width:736,sport:'cardio',metric:'distance',data:'4.2',phase:'stale'},
    {name:'ended',width:736,sport:'strength',metric:'weight',data:'60',phase:'ended'}
  ];
  for(const config of configs){
    await page.setViewportSize({width:config.width,height:4000});
    const failures=await root.evaluate((root,c)=>{
      function set(id,value){const el=root.querySelector(id);el.value=value;el.dispatchEvent(new Event('change',{bubbles:true}));}
      set('#ls-sport',c.sport);set('#ls-primary',c.metric);set('#ls-data',c.data);root.querySelector(`[data-phase="${c.phase}"]`).click();
      const stage=root.querySelector('[data-direction=glam]'),grid=stage.querySelector('.ls-grid'),failures=[];
      if(document.documentElement.scrollWidth>innerWidth+1)failures.push('horizontal overflow');
      for(const el of grid.querySelectorAll('.ls-slot,.ls-selected-value,.ls-big-time')){
        const range=document.createRange();range.selectNodeContents(el);
        if(range.getBoundingClientRect().width>el.getBoundingClientRect().width+1)failures.push('value overflow '+el.textContent);
      }
      if(c.phase==='stale'&&grid.querySelector('.ls-impact-main,.ls-metrics'))failures.push('stale metrics');
      if(c.phase==='ended'&&grid.querySelector('.ls-lock,.ls-island-expanded'))failures.push('ended activity remains');
      if(c.phase==='running'&&c.data==='missing'&&grid.querySelector('.ls-selected-value'))failures.push('missing sport metric remains');
      if(c.phase==='running'&&c.data!=='missing'&&!grid.querySelector('.ls-selected-value'))failures.push('received value missing');
      if(stage.querySelector('i[data-lucide]'))failures.push('missing icon');
      return failures;
    },config);
    report.cases.push({...config,failures});console.log(config.name,failures.length?'FAILED':'passed');
    if(config.capture){const name=`live-activity-gold-${config.name}.png`;await frame.locator('[data-direction=glam] .ls-grid').screenshot({path:path.join(__dirname,name),timeout:5000});report.screenshots.push(name);}
  }
  report.status=report.error||report.cases.some(c=>c.failures.length)?'failed':'passed';
})().catch(e=>{report.status='incomplete';report.error=e.message.split('\n')[0];}).finally(async()=>{clearTimeout(deadline);save();if(browser)await browser.close();console.log(JSON.stringify({status:report.status,cases:report.cases.length}));process.exitCode=report.status==='passed'?0:1;});
