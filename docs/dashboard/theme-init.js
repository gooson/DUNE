(() => {
  let preference='system',sidebar='expanded';
  try {preference=localStorage.getItem('dune-dashboard-appearance')||'system';sidebar=localStorage.getItem('dune-dashboard-sidebar')||'expanded';} catch {}
  if(!['system','light','dark'].includes(preference))preference='system';
  document.documentElement.dataset.themePreference=preference;
  document.documentElement.dataset.theme=preference==='system'?(matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light'):preference;
  document.documentElement.dataset.sidebar=sidebar==='collapsed'?'collapsed':'expanded';
})();
