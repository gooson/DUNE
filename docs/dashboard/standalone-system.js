(() => {
  'use strict';
  const config=__DUNE_DOCUMENT_CONFIG__;
  const media=matchMedia('(prefers-color-scheme:dark)');
  let preference='system',mode;
  const saved=()=>{try{return localStorage.getItem('dune-dashboard-appearance')||'system';}catch{return preference;}};
  const resolve=()=>preference==='system'?(media.matches?'dark':'light'):preference;
  const sendMode=frame=>frame.contentWindow?.postMessage({type:'dune:appearance',mode,preference},'*');
  function apply(nextMode){
    mode=nextMode||resolve();
    window.DUNEDocumentUX.enhance(document,{selectors:config.selectors});
    document.documentElement.dataset.duneDocumentSystem='1';
    document.documentElement.dataset.duneProfile=config.profile;
    document.documentElement.dataset.theme=mode;
    document.documentElement.dataset.themePreference=preference;
    document.querySelectorAll('iframe').forEach(sendMode);
  }
  const sync=()=>{preference=saved();if(!['system','light','dark'].includes(preference))preference='system';apply();};
  const ready=()=>{
    sync();
    parent.postMessage({type:'dune:ready'},'*');
    new MutationObserver(changes=>{
      if(changes.some(change=>change.type==='childList'))window.DUNEDocumentUX.enhance(document,{selectors:config.selectors});
      if(document.documentElement.dataset.theme!==mode)apply(mode);
    }).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['data-theme']});
    document.addEventListener('keydown',event=>{if(parent!==window&&(event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='k'){event.preventDefault();parent.postMessage({type:'dune:command'},'*');}});
    document.addEventListener('click',event=>{
      if(event.defaultPrevented||event.button!==0||event.metaKey||event.ctrlKey||event.shiftKey||event.altKey||parent===window)return;
      const a=event.target.closest?.('a[href]');if(!a||a.hasAttribute('download')||a.getAttribute('href').startsWith('#'))return;
      try{const url=new URL(a.getAttribute('href'),config.base);if(url.origin!==new URL(config.base).origin)return;parent.postMessage({type:'dune:document',url:url.href},'*');event.preventDefault();}catch{}
    });
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ready,{once:true});else ready();
  media.addEventListener('change',()=>{if(preference==='system')apply();});
  addEventListener('storage',event=>{if(event.key==='dune-dashboard-appearance')sync();});
  addEventListener('message',event=>{
    if(!event.data)return;
    const child=[...document.querySelectorAll('iframe')].find(frame=>frame.contentWindow===event.source);
    if(child){
      if(event.data.type==='dune:ready')sendMode(child);
      if(event.data.type==='dune:command'&&parent!==window)parent.postMessage({type:'dune:command'},'*');
      if(event.data.type==='dune:document'&&typeof event.data.url==='string'){
        try{const url=new URL(event.data.url,config.base);if(url.origin!==new URL(config.base).origin)return;if(parent===window)location.href=url.href;else parent.postMessage({type:'dune:document',url:url.href},'*');}catch{}
      }
      return;
    }
    if(event.source!==parent||event.data.type!=='dune:appearance'||!['light','dark'].includes(event.data.mode))return;
    preference=['system','light','dark'].includes(event.data.preference)?event.data.preference:event.data.mode;
    apply(event.data.mode);
  });
})();
