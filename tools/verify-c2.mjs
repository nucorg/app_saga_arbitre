import {connect} from './cdp.mjs';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const app=process.env.SAGA_APP || fileURLToPath(new URL('../',import.meta.url));
const dir=app+'/docs/validation/c2/';mkdirSync(dir,{recursive:true});
const example=JSON.parse(readFileSync(app+'/data/scenarios/veille-c2.json'));
const ids=Object.keys(example.inputs);
const c=await connect(Number(process.env.CHROME_PORT || 9366));
const observations=[];
const assert=(ok,msg)=>{if(!ok)throw Error(msg);};
async function settled(condition){await c.until(`(${condition}) && !document.documentElement.classList.contains('shiny-busy') && ![...document.querySelectorAll('.recalculating')].some(e=>e.getClientRects().length)`);}
async function tab(label){await c.evaluate(`Array.from(document.querySelectorAll('a.nav-link')).find(e=>e.textContent.trim()===${JSON.stringify(label)}).click()`);}
async function click(id){
  await c.evaluate(`document.getElementById(${JSON.stringify(id)}).click()`);
  const label=id==='c2_to_monthly'?'Manuel vs Agentique':id==='c2_to_ctp'?"Diagnostic d'Investissement (CTP)":null;
  if(label) await settled(`document.querySelector('a.nav-link.active')?.textContent.trim()===${JSON.stringify(label)}`);
}
async function set(values){await c.evaluate(`(()=>{for(const[id,value]of Object.entries(${JSON.stringify(values)})){const e=document.getElementById(id);if(e.type==='checkbox')e.checked=value;else e.value=value===null?'':value;e.dispatchEvent(new Event('change',{bubbles:true}));}})()`);}
async function check(id,value){await settled(`document.getElementById(${JSON.stringify(id)})?.dataset.value===${JSON.stringify(String(value))}`);}
async function state(name){observations.push({case:name,...await c.evaluate(`({inputs:Object.fromEntries(${JSON.stringify(ids)}.map(id=>[id,document.getElementById(id).value])),total:document.getElementById('c2-total')?.dataset.value || null,status:document.getElementById('c2-status')?.innerText || null,monthly:document.getElementById('cost_orch').value,ctp:document.getElementById('ctp_orch').value,ctpDetailed:document.getElementById('ctp_detailed').checked,kappa:document.getElementById('ctp_kappa').value,activeTab:document.querySelector('a.nav-link.active')?.textContent.trim(),buttons:[...document.querySelectorAll('#c2_transfer_actions button')].map(e=>({id:e.id,disabled:e.disabled}))})`)});}
async function shot(name,selector){
  const clip=selector?await c.evaluate(`(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return{x:r.x+scrollX,y:r.y+scrollY,width:r.width,height:r.height,scale:1}})()`):null;
  const r=await c.call('Page.captureScreenshot',{format:'png',captureBeyondViewport:!!clip,...(clip?{clip}:{})});
  writeFileSync(dir+name,Buffer.from(r.data,'base64'));
}
try{
  await c.call('Page.enable');await c.call('Network.enable');await c.call('Network.setBlockedURLs',{urls:['https://*']});
  await c.call('Emulation.setDeviceMetricsOverride',{width:1440,height:1400,deviceScaleFactor:1,mobile:false});
  await c.call('Page.navigate',{url:process.env.SAGA_URL || 'http://127.0.0.1:3866'});
  await c.until(`window.Shiny?.shinyapp?.$socket?.readyState===1 && !!document.getElementById('load_c2_example')`);
  await tab('C2 - Infra');
  await settled(`document.getElementById('c2-status') && document.getElementById('c2_to_monthly')?.disabled && document.getElementById('c2_to_ctp')?.disabled`);
  assert(await c.evaluate(`${JSON.stringify(ids)}.every(id=>document.getElementById(id).value==='')`),'Les postes initiaux doivent être inconnus');
  await state('budget-inconnu');await shot('capture-initiale.png');
  await set({c2_runtime:0});await settled(`document.getElementById('c2-status').innerText.includes('1 poste')`);await state('un-poste-nul-cinq-inconnus');
  await tab('Manuel vs Agentique');await click('load_monthly_example');await check('monthly-analytical',16500);
  await tab("Diagnostic d'Investissement (CTP)");await click('load_ctp_example');await check('ctp-project',144000);
  await set({ctp_detailed:false,ctp_kappa:4});await check('ctp-exploitation',151200);
  await tab('C2 - Infra');await click('load_c2_example');await check('c2-total',2400);await state('exemple-2400');
  assert(await c.evaluate(`document.querySelectorAll('.saga-c2-bars li').length===6 && document.querySelectorAll('.saga-c2-table').length===0`),'Les six postes doivent être visibles');
  assert(await c.evaluate(`Number(document.getElementById('ctp_kappa').value)===4 && !document.getElementById('ctp_detailed').checked`),'Le chargement C2 doit préserver le scénario CTP');
  await c.until(`!document.querySelector('.shiny-notification')`);await shot('capture-desktop.png');await shot('capture-budget.png','#c2-result-card');
  await click('c2_to_ctp');await check('ctp-exploitation',108000);await check('ctp-project',144000);await check('ctp-balance',9000);await state('report-ctp-sans-majoration');
  assert(await c.evaluate(`document.getElementById('ctp_detailed').checked && Number(document.getElementById('ctp_kappa').value)===1 && document.querySelector('a.nav-link.active').textContent.trim() === "Diagnostic d'Investissement (CTP)"`),'Le report CTP doit sélectionner un total sans majoration');
  await tab('C2 - Infra');await click('c2_to_monthly');await check('monthly-current',15000);await check('monthly-analytical',16500);await state('report-mensuel');
  assert(await c.evaluate(`document.querySelector('a.nav-link.active').textContent.trim()==='Manuel vs Agentique'`),'Le report mensuel doit sélectionner son onglet');
  await tab('C2 - Infra');await set({c2_sources:710.25});await check('c2-total',2410.25);await state('centimes-sans-synchronisation');
  assert(await c.evaluate(`Number(document.getElementById('cost_orch').value)===2400 && Number(document.getElementById('ctp_orch').value)===2400`),'Les autres onglets ne doivent pas suivre automatiquement C2');
  await click('c2_to_monthly');await check('monthly-current',15010.25);await check('monthly-analytical',16510.25);await state('report-des-centimes');
  assert(await c.evaluate(`Number(document.getElementById('cost_orch').value)===2410.25 && Number(document.getElementById('ctp_orch').value)===2400`),'Le report doit conserver les centimes et limiter sa cible');
  await tab('C2 - Infra');await set({c2_sources:-1});await settled(`!document.getElementById('c2-total') && document.getElementById('c2_to_monthly')?.disabled && document.getElementById('c2_budget').innerText.includes('Montant invalide')`);await state('montant-negatif');
  await click('clear_c2');await settled(`${JSON.stringify(ids)}.every(id=>document.getElementById(id).value==='') && document.getElementById('c2-status').innerText.includes('0 postes')`);await state('effacement');
  assert(await c.evaluate(`Number(document.getElementById('cost_orch').value)===2410.25 && Number(document.getElementById('ctp_orch').value)===2400`),'L’effacement doit préserver les calculs déjà reportés');
  await set(Object.fromEntries(ids.map(id=>[id,0])));await check('c2-total',0);await settled(`!!document.getElementById('c2-zero') && !document.getElementById('c2_to_ctp').disabled`);
  assert(await c.evaluate(`document.querySelectorAll('.saga-c2-bars').length===0`),'Un budget nul ne doit pas produire de barres invalides');await state('budget-explicitement-nul');
  await click('c2_to_ctp');await check('ctp-exploitation',93600);await state('report-budget-nul');
  await tab('C2 - Infra');await click('load_c2_example');await check('c2-total',2400);
  await c.evaluate(`document.getElementById('c2_runtime').focus()`);
  await c.call('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});await c.call('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
  assert(await c.evaluate(`document.activeElement.id==='c2_storage'`),'La navigation clavier doit suivre les postes');
  await c.evaluate(`document.getElementById('c2_to_monthly').focus()`);
  await c.call('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',text:'\r',windowsVirtualKeyCode:13});await c.call('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13});
  await check('monthly-current',15000);await state('report-au-clavier');
  await tab('C2 - Infra');await c.until(`!document.querySelector('.shiny-notification')`);
  const layouts=[];
  for(const width of [1280,390]){
    await c.call('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
    await c.evaluate(`window.dispatchEvent(new Event('resize'));new Promise(r=>setTimeout(r,700))`);
    const layout=await c.evaluate(`({width:innerWidth,documentWidth:document.documentElement.scrollWidth,cardWidth:document.getElementById('c2-result-card').getBoundingClientRect().width})`);
    assert(layout.documentWidth<=width && layout.cardWidth<=width,'Débordement horizontal C2');layouts.push(layout);await shot(`capture-${width}.png`);
    if(width===390){
      for(const [open,name] of [[true,'capture-mobile-saisie.png'],[false,'capture-mobile-budget.png']]){
        await c.evaluate(`(()=>{const b=document.querySelector('.tab-pane.active button.collapse-toggle');if((b.getAttribute('aria-expanded')==='true')!==${open})b.click();return new Promise(r=>setTimeout(r,750));})()`);
        const mobile=await c.evaluate(`({open:document.querySelector('.tab-pane.active button.collapse-toggle').getAttribute('aria-expanded')==='true',width:innerWidth,documentWidth:document.documentElement.scrollWidth})`);
        assert(mobile.open===open && mobile.documentWidth<=mobile.width,'Volet mobile inaccessible ou débordant');layouts.push(mobile);
        await shot(name);
      }
    }
  }
  const tabs=await c.evaluate(`[...document.querySelectorAll('a.nav-link[data-bs-toggle="tab"]')].map(e=>e.textContent.trim())`);
  assert(tabs.length===(app.includes('terrain')?8:6),'Nombre d’onglets divergent');
  assert(await c.evaluate(`!document.getElementById('infra_select') && !document.getElementById('plot_c2_breakdown')`),'L’ancienne interface CSV doit disparaître');
  assert(await c.evaluate(`![...document.querySelectorAll('.tab-pane.active .shiny-output-error')].length`),'Erreur Shiny visible');
  const files=['R/logic_infra.R','R/ui.R','R/server.R','app.R','data/scenarios/veille-c2.json'];
  const report={date:new Date().toISOString(),app,base_commit:execFileSync('git',['-C',app,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),source_sha256:Object.fromEntries(files.map(f=>[f,createHash('sha256').update(readFileSync(app+'/'+f)).digest('hex')])),browser:await c.call('Browser.getVersion'),layouts,tabs,observations};
  writeFileSync(dir+'verification-interface.json',JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({status:'OK',checks:observations.length,layouts}));
}finally{c.close();}
