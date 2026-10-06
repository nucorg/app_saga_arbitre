import {connect} from './cdp.mjs';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const app=process.env.SAGA_APP || fileURLToPath(new URL('../',import.meta.url));
const dir=app+'/docs/validation/ctp/';mkdirSync(dir,{recursive:true});
const scenario=JSON.parse(readFileSync(app+'/data/scenarios/veille-ctp-section-1.json'));
const c=await connect(Number(process.env.CHROME_PORT || 9364));
const observations=[];
const assert=(ok,msg)=>{if(!ok)throw Error(msg);};
async function settled(condition){await c.until(`(${condition}) && !document.documentElement.classList.contains('shiny-busy') && ![...document.querySelectorAll('.recalculating')].some(e=>e.getClientRects().length)`);}
async function set(values){await c.evaluate(`(()=>{for(const[id,value]of Object.entries(${JSON.stringify(values)})){const e=document.getElementById(id);if(e.type==='checkbox')e.checked=value;else e.value=value===null?'':value;e.dispatchEvent(new Event('change',{bubbles:true}));}})()`);}
async function check(id,value){await settled(`document.getElementById(${JSON.stringify(id)})?.dataset.value === ${JSON.stringify(String(value))}`);}
async function state(name){observations.push({case:name,...await c.evaluate(`({inputs:Object.fromEntries(${JSON.stringify(Object.keys(scenario.inputs))}.map(id=>{const e=document.getElementById(id);return [id,e.type==='checkbox'?e.checked:(e.value===''?null:Number(e.value))]})),summary:document.getElementById('ctp_summary').innerText,balance:document.getElementById('ctp_balance_summary').innerText})`)});}
async function example(){await c.evaluate(`document.getElementById('load_ctp_example').click()`);await check('ctp-project',144000);await check('ctp-balance',9000);}
async function shot(name,selector){
  let clip;
  if(selector)clip=await c.evaluate(`(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return{x:r.x+scrollX,y:r.y+scrollY,width:r.width,height:r.height,scale:1}})()`);
  const r=await c.call('Page.captureScreenshot',{format:'png',captureBeyondViewport:!!clip,...(clip?{clip}:{})});
  writeFileSync(dir+name,Buffer.from(r.data,'base64'));return clip;
}
try{
  await c.call('Page.enable');await c.call('Network.enable');await c.call('Network.setBlockedURLs',{urls:['https://*']});
  await c.call('Emulation.setDeviceMetricsOverride',{width:1440,height:1500,deviceScaleFactor:1,mobile:false});
  await c.call('Page.navigate',{url:process.env.SAGA_URL || 'http://127.0.0.1:3864'});
  await c.until(`window.Shiny?.shinyapp?.$socket?.readyState===1 && !!document.getElementById('load_ctp_example')`);
  await c.evaluate(`Array.from(document.querySelectorAll('a.nav-link')).find(e=>e.textContent.trim()==="Diagnostic d'Investissement (CTP)").click();document.getElementById('ctp-balance-panel').open=true;`);
  await example();await state('nominal');
  for(const[id,value]of Object.entries(scenario.inputs))assert(observations[0].inputs[id]===value,'Paramètre divergent : '+id);
  assert(observations[0].summary.includes('144\u202f000'),'Formatage incorrect du total projet');
  await settled(`document.getElementById('plot_ctp_cumulative')?.data?.some(t=>t.y?.includes(144000))`);
  await c.until(`!document.querySelector('.shiny-notification')`);
  await shot('capture-originale.png');
  const crop=await shot('capture-ctp.png','#ctp-result-card');
  const balanceCrop=await shot('capture-solde.png','#ctp-balance-panel');
  await set({ctp_calibration:2});await check('ctp-exploitation',102000);await check('ctp-balance',12000);await state('calibrage-2-mois');
  await set({ctp_calibration:3,ctp_alpha:10});await check('ctp-balance',-41400);await check('ctp-project',144000);await state('alpha-10pct');
  await set({ctp_investment:null});await check('ctp-project','unknown');await check('ctp-balance','unknown');await check('ctp-exploitation',108000);await state('investissement-inconnu');
  await set({ctp_investment:0,ctp_alpha:50});await check('ctp-project',108000);await check('ctp-balance',45000);await state('investissement-nul');
  await example();await set({ctp_calibration:0});await check('ctp-project',126000);await check('ctp-balance',18000);await state('sans-calibrage');
  await set({ctp_calibration:12});await check('ctp-project',162000);await check('ctp-balance',0);await state('calibrage-hors-horizon');
  await set({ctp_t:1});await check('ctp-exploitation',21000);await state('horizon-1-mois');
  await example();await set({ctp_h1:700});await check('ctp-project',216000);await check('ctp-balance',-36000);await state('surcharge-calibrage');
  await example();await set({ctp_detailed:false,ctp_kappa:4});await check('ctp-exploitation',151200);await state('C2-coefficient-explicite');
  await set({ctp_detailed:true});await check('ctp-exploitation',108000);await state('C2-total-ignore-coefficient');
  await set({ctp_t:0});await settled(`document.getElementById('ctp_summary').innerText.includes('horizon')`);await state('horizon-invalide');
  await example();await c.until(`!document.querySelector('.shiny-notification')`);
  const layouts=[];
  for(const width of [1280,390]){
    await c.call('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
    await c.evaluate(`window.dispatchEvent(new Event('resize'));new Promise(r=>setTimeout(r,700))`);
    const layout=await c.evaluate(`({width:innerWidth,documentWidth:document.documentElement.scrollWidth,cardWidth:document.getElementById('ctp-result-card').getBoundingClientRect().width})`);
    assert(layout.documentWidth<=width && layout.cardWidth<=width,'Débordement de la page');layouts.push(layout);
    await shot(`capture-${width}.png`);
  }
  await c.call('Emulation.setDeviceMetricsOverride',{width:1440,height:1500,deviceScaleFactor:1,mobile:false});
  const tabs=await c.evaluate(`[...document.querySelectorAll('a.nav-link[data-bs-toggle="tab"]')].map(e=>e.textContent.trim())`);
  assert(tabs.length===(app.includes('terrain')?8:6),'Nombre d’onglets divergent');
  for(const [label,id] of [['Manuel vs Agentique','monthly_summary'],['C1 - Inférence','plot_c1_compare'],['C2 - Infra','plot_c2_breakdown'],['C3 - Humain','plot_c3_asym'],['Prix API','table_pricing_edit']]){
    await c.evaluate(`Array.from(document.querySelectorAll('a.nav-link')).find(e=>e.textContent.trim()===${JSON.stringify(label)}).click()`);
    await settled(`document.getElementById(${JSON.stringify(id)})?.innerHTML.length>0`);
    const errors=await c.evaluate(`[...document.querySelectorAll('.tab-pane.active .shiny-output-error')].map(e=>e.textContent)`);
    assert(!errors.length,`Erreur dans ${label}: ${errors.join(';')}`);observations.push({case:'autre-onglet',label,errors});
  }
  const files=['R/logic_maths.R','R/logic_ctp.R','R/ui.R','R/server.R','app.R','data/scenarios/veille-ctp-section-1.json'];
  const report={date:new Date().toISOString(),app,base_commit:execFileSync('git',['-C',app,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),source_sha256:Object.fromEntries(files.map(f=>[f,createHash('sha256').update(readFileSync(app+'/'+f)).digest('hex')])),browser:await c.call('Browser.getVersion'),viewport:{width:1440,height:1500},crop,balanceCrop,layouts,tabs,observations};
  writeFileSync(dir+'verification-interface.json',JSON.stringify(report,null,2)+'\n');
  writeFileSync(dir+'scenario.json',JSON.stringify(scenario,null,2)+'\n');
  console.log(JSON.stringify({status:'OK',checks:observations.length,layouts}));
}finally{c.close();}
