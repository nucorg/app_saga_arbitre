import {connect} from './cdp.mjs';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const app=process.env.SAGA_APP || fileURLToPath(new URL('../',import.meta.url));
const dir=app+'/docs/validation/c1-c3/';mkdirSync(dir,{recursive:true});
const c=await connect(Number(process.env.CHROME_PORT || 9366));
const observations=[],layouts=[];
const assert=(ok,msg)=>{if(!ok)throw Error(msg);};
async function settled(condition){await c.until(`(${condition}) && !document.documentElement.classList.contains('shiny-busy') && ![...document.querySelectorAll('.recalculating')].some(e=>e.getClientRects().length)`);}
async function tab(label){await c.evaluate(`Array.from(document.querySelectorAll('a.nav-link')).find(e=>e.textContent.trim()===${JSON.stringify(label)}).click()`);await settled(`document.querySelector('a.nav-link.active')?.textContent.trim()===${JSON.stringify(label)}`);}
async function click(id){await c.evaluate(`document.getElementById(${JSON.stringify(id)}).click()`);if(/_to_/.test(id)){const label=id.endsWith('monthly')?'Manuel vs Agentique':"Diagnostic d'Investissement (CTP)";await settled(`document.querySelector('a.nav-link.active')?.textContent.trim()===${JSON.stringify(label)}`);}}
async function set(values){await c.evaluate(`(()=>{for(const[id,value]of Object.entries(${JSON.stringify(values)})){const e=document.getElementById(id);e.value=value===null?'':value;e.dispatchEvent(new Event('change',{bubbles:true}));}})()`);}
async function radio(id,value){await c.evaluate(`document.querySelector(${JSON.stringify('#'+id+' input[value="'+value+'"]')}).click()`);}
async function metric(id,value){await settled(`Math.abs(Number(document.getElementById(${JSON.stringify(id)})?.dataset.value)-${value})<1e-8`);}
async function input(id,value){await settled(`Math.abs(Number(document.getElementById(${JSON.stringify(id)}).value)-${value})<1e-8`);}
async function state(name){observations.push({case:name,...await c.evaluate(`({tab:document.querySelector('a.nav-link.active')?.textContent.trim(),c1:document.getElementById('c1-total')?.dataset.value || null,h1:document.getElementById('c3-h1')?.dataset.value || null,h2:document.getElementById('c3-h2')?.dataset.value || null,monthly:Object.fromEntries(['cost_c1_month','maint_h','cost_h','vol'].map(id=>[id,document.getElementById(id).value])),ctp:Object.fromEntries(['ctp_c1_month','ctp_h1','ctp_h2','ctp_w','ctp_v','ctp_calibration','ctp_t'].map(id=>[id,document.getElementById(id).value]))})`)});}
async function shot(name,selector){
  const clip=selector?await c.evaluate(`(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return{x:r.x+scrollX,y:r.y+scrollY,width:r.width,height:r.height,scale:1}})()`):null;
  const r=await c.call('Page.captureScreenshot',{format:'png',captureBeyondViewport:!!clip,...(clip?{clip}:{})});writeFileSync(dir+name,Buffer.from(r.data,'base64'));
}
async function screenshots(component){
  await c.until(`!document.querySelector('.shiny-notification')`);
  await c.call('Emulation.setDeviceMetricsOverride',{width:1440,height:1250,deviceScaleFactor:1,mobile:false});
  await c.evaluate(`window.dispatchEvent(new Event('resize'));new Promise(r=>setTimeout(r,500))`);
  await shot(component+'-desktop.png');await shot(component+'-resultat.png','#'+component+'-result-card');
  for(const width of [1280,390]){
    await c.call('Emulation.setDeviceMetricsOverride',{width,height:1050,deviceScaleFactor:1,mobile:false});
    await c.evaluate(`window.dispatchEvent(new Event('resize'));new Promise(r=>setTimeout(r,600))`);
    const layout=await c.evaluate(`({width:innerWidth,documentWidth:document.documentElement.scrollWidth,cardWidth:document.getElementById('${component}-result-card').getBoundingClientRect().width})`);
    assert(layout.documentWidth<=width && layout.cardWidth<=width,'Débordement '+component);layouts.push({component,...layout});
    if(width===390){
      for(const [open,name] of [[true,'saisie'],[false,'resultat']]){
        await c.evaluate(`(()=>{const b=document.querySelector('.tab-pane.active button.collapse-toggle');if((b.getAttribute('aria-expanded')==='true')!==${open})b.click();return new Promise(r=>setTimeout(r,750));})()`);
        assert(await c.evaluate(`document.documentElement.scrollWidth<=innerWidth`),'Débordement du volet mobile');await shot(component+'-mobile-'+name+'.png');
      }
    }
  }
  await c.call('Emulation.setDeviceMetricsOverride',{width:1440,height:1250,deviceScaleFactor:1,mobile:false});
}
try{
  await c.call('Page.enable');await c.call('Network.enable');await c.call('Network.setBlockedURLs',{urls:['https://*']});
  await c.call('Emulation.setDeviceMetricsOverride',{width:1440,height:1250,deviceScaleFactor:1,mobile:false});
  await c.call('Page.navigate',{url:process.env.SAGA_URL || 'http://127.0.0.1:3866'});
  await c.until(`window.Shiny?.shinyapp?.$socket?.readyState===1 && !!document.getElementById('load_c3_example')`);
  await tab('C3 - Humain');await settled(`document.getElementById('c3_to_monthly')?.disabled && document.getElementById('c3_to_ctp')?.disabled`);await state('C3-inconnu');
  await tab('Manuel vs Agentique');await click('load_monthly_example');await metric('monthly-analytical',16500);
  await tab("Diagnostic d'Investissement (CTP)");await click('load_ctp_example');await metric('ctp-project',144000);
  await tab('C1 - Inférence');await click('load_c1_example');await metric('c1-total',10.56);await metric('c1-call',.0044);await state('C1-modele-A-deux-appels');
  await settled(`document.getElementById('plot_c1_compare')?.data?.length>0`);await screenshots('c1');
  await click('c1_to_monthly');await input('cost_c1_month',10.56);await state('C1-report-mensuel');
  assert(await c.evaluate(`Number(document.getElementById('vol').value)===1200 && Number(document.getElementById('maint_h').value)===200`),'C1 ne doit modifier que son budget');
  await tab('C1 - Inférence');await radio('c1_selected','B');await metric('c1-total',52.8);await state('C1-selection-B-sans-synchronisation');
  assert(await c.evaluate(`Number(document.getElementById('cost_c1_month').value)===10.56 && Number(document.getElementById('ctp_c1_month').value)===600`),'Synchronisation C1 non voulue');
  await click('c1_to_ctp');await input('ctp_c1_month',52.8);await state('C1-report-CTP');
  assert(await c.evaluate(`Number(document.getElementById('ctp_v').value)===1200 && Number(document.getElementById('ctp_t').value)===6`),'Le report C1 doit préserver le contexte CTP');
  await tab('C1 - Inférence');await set({c1_usd_eur:0});await settled(`!document.getElementById('c1-total') && document.getElementById('c1_to_monthly').disabled && document.getElementById('c1_to_ctp').disabled`);await state('C1-taux-invalide');
  await set({c1_usd_eur:.88,c1_calls:0});await metric('c1-total',0);await click('c1_to_monthly');await input('cost_c1_month',0);await state('C1-report-nul');
  await tab('C3 - Humain');await click('load_c3_example');await metric('c3-h1',300);await metric('c3-h2',200);await state('C3-exemple');
  await settled(`document.getElementById('plot_c3_asym')?.data?.length>0`);await screenshots('c3');
  await click('c3_to_monthly');await input('maint_h',200);await input('cost_h',60);await state('C3-report-croisiere');
  await tab('C3 - Humain');await radio('c3_monthly_phase','calibrage');await settled(`document.getElementById('c3_summary').innerText.includes('report mensuel : calibrage')`);
  assert(await c.evaluate(`Number(document.getElementById('maint_h').value)===200`),'La sélection de phase doit attendre un report');
  await click('c3_to_monthly');await input('maint_h',300);await state('C3-report-calibrage');
  await tab("Diagnostic d'Investissement (CTP)");await set({ctp_calibration:2,ctp_t:12,ctp_h1:1,ctp_h2:2,ctp_w:3});await input('ctp_w',3);
  await tab('C3 - Humain');await click('c3_to_ctp');await input('ctp_h1',300);await input('ctp_h2',200);await input('ctp_w',60);await state('C3-report-deux-phases');
  assert(await c.evaluate(`Number(document.getElementById('ctp_calibration').value)===2 && Number(document.getElementById('ctp_t').value)===12 && Number(document.getElementById('ctp_c1_month').value)===52.8`),'C3 doit conserver horizon, durée et C1');
  await tab('C3 - Humain');await set({c3_review:null});await settled(`!document.getElementById('c3-h2') && document.getElementById('c3_to_ctp').disabled`);await state('C3-revue-inconnue');
  await set({c3_review:5,c3_escalade:101});await settled(`document.getElementById('c3_to_monthly').disabled && document.getElementById('c3_summary').innerText.includes('invalide')`);await state('C3-taux-invalide');
  const x=JSON.parse(readFileSync(app+'/data/scenarios/c3-estimation.json')).inputs;await set(Object.fromEntries(Object.keys(x).map(id=>[id,0])));await metric('c3-h2',0);await click('c3_to_ctp');await input('ctp_h2',0);await input('ctp_w',0);await state('C3-report-nul');
  await tab('C3 - Humain');await click('load_c3_example');await metric('c3-h2',200);
  await c.evaluate(`(()=>{const b=document.querySelector('.tab-pane.active button.collapse-toggle');if(b.getAttribute('aria-expanded')!=='true')b.click();return new Promise(r=>setTimeout(r,750));})()`);
  await c.evaluate(`document.getElementById('c3_v').focus()`);await c.call('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});await c.call('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
  assert(await c.evaluate(`document.activeElement.id==='c3_w'`),'Ordre de navigation clavier C3 incorrect');
  await c.evaluate(`document.getElementById('c3_to_monthly').focus()`);await c.call('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',text:'\r',windowsVirtualKeyCode:13});await c.call('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13});
  await settled(`document.querySelector('a.nav-link.active')?.textContent.trim()==='Manuel vs Agentique'`);await input('maint_h',200);await state('C3-report-au-clavier');
  const tabs=await c.evaluate(`[...document.querySelectorAll('a.nav-link[data-bs-toggle="tab"]')].map(e=>e.textContent.trim())`);
  assert(tabs.length===(app.includes('terrain')?8:6),'Nombre d’onglets divergent');
  const files=['R/logic_components.R','R/ui.R','R/server.R','app.R','data/scenarios/c1-estimation.json','data/scenarios/c3-estimation.json','data/pricing_models.csv'];
  const report={date:new Date().toISOString(),app,base_commit:execFileSync('git',['-C',app,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),source_sha256:Object.fromEntries(files.map(f=>[f,createHash('sha256').update(readFileSync(app+'/'+f)).digest('hex')])),browser:await c.call('Browser.getVersion'),layouts,tabs,observations};
  writeFileSync(dir+'verification-interface.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({status:'OK',checks:observations.length,layouts}));
}finally{c.close();}
