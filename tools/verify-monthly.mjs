// Vérification dans Shiny et captures réelles, sans modification du contenu affiché.
// Démarrer Shiny (3854) et Chrome/CDP (9354) avant ce script ; détails dans notice.md.
import {connect} from './cdp.mjs';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const dir = fileURLToPath(new URL('../docs/validation/cout-mensuel/', import.meta.url));
mkdirSync(dir, {recursive:true});
const app = process.env.SAGA_APP || fileURLToPath(new URL('../', import.meta.url));
const scenario = JSON.parse(readFileSync(`${app}/data/scenarios/veille-section-1.json`));
const c = await connect(Number(process.env.CHROME_PORT || 9354));
const observations = [];
function assert(ok, message) { if (!ok) throw Error(message); }
async function value(id, n) {
  await c.evaluate(`(() => { const el = document.getElementById(${JSON.stringify(id)}); if (el.selectize) { el.selectize.setValue(${JSON.stringify(n)}); } else { el.value = ${JSON.stringify(n)}; el.dispatchEvent(new Event('change', {bubbles:true})); } })()`);
}
async function settled(expression) {
  await c.until(`(${expression}) && !document.documentElement.classList.contains('shiny-busy') && ![...document.querySelectorAll('.recalculating')].some(el => el.getClientRects().length)`);
}
async function check(amount) {
  await settled(`Number(document.getElementById('monthly-analytical')?.dataset.value) === ${amount}`);
}
async function state() {
  return c.evaluate(`({inputs: Object.fromEntries(${JSON.stringify(Object.keys(scenario.inputs))}.map(id => [id, Number(document.getElementById(id).value)])), current: Number(document.getElementById('monthly-current').dataset.value), allocation: Number(document.getElementById('monthly-allocation').dataset.value), analytical: Number(document.getElementById('monthly-analytical').dataset.value), unitCurrent: Number(document.getElementById('monthly-unit-current')?.dataset.value), unitAnalytical: Number(document.getElementById('monthly-unit-analytical')?.dataset.value), text: document.getElementById('monthly-result-card').innerText})`);
}
try {
  await c.call('Page.enable');
  await c.call('Network.enable');
  await c.call('Network.setBlockedURLs', {urls:['https://*']});
  await c.call('Emulation.setDeviceMetricsOverride', {width:1440, height:1400, deviceScaleFactor:1, mobile:false});
  await c.call('Page.navigate', {url:process.env.SAGA_URL || 'http://127.0.0.1:3854'});
  await c.until(`window.Shiny?.shinyapp?.$socket?.readyState === 1 && !!document.getElementById('load_monthly_example')`);
  await c.evaluate(`document.getElementById('load_monthly_example').click()`);
  await check(16500);
  await settled(`document.querySelector('#plot_ctask')?.data?.some(t => t.y?.includes(13.75))`);
  const nominal = await state();
  for (const [id, v] of Object.entries(scenario.inputs)) assert(nominal.inputs[id] === v, `Paramètre divergent : ${id}`);
  assert(nominal.current === 15000 && nominal.allocation === 1500 && nominal.unitCurrent === 12.5 && nominal.unitAnalytical === 13.75, 'Résultats nominaux divergents');
  assert(nominal.text.includes('16\u202f500') && nominal.text.includes('13,75'), 'Formatage des montants divergent');
  observations.push({case:'nominal', ...nominal});
  // Attendre la fermeture naturelle de la notification avant la capture.
  await c.until(`!document.querySelector('.shiny-notification')`);
  const raw = await c.call('Page.captureScreenshot', {format:'png', captureBeyondViewport:false});
  writeFileSync(dir+'capture-originale.png', Buffer.from(raw.data, 'base64'));
  const rect = await c.evaluate(`(() => {const r=document.getElementById('monthly-result-card').getBoundingClientRect();return {x:r.x+scrollX,y:r.y+scrollY,width:r.width,height:r.height,scale:1};})()`);
  const crop = await c.call('Page.captureScreenshot', {format:'png', captureBeyondViewport:true, clip:rect});
  writeFileSync(dir+'capture-resultats.png', Buffer.from(crop.data, 'base64'));

  await c.evaluate(`document.getElementById('add_scen').click()`);
  await settled(`document.querySelector('#plot_ctask')?.data?.some(t => t.x?.length >= 2)`);
  await value('maint_h', 300); await check(22500);
  observations.push({case:'charge-humaine-300h', ...await state()});
  await c.evaluate(`document.querySelector('#monthly_saved').closest('details').open = true`);
  await settled(`document.querySelector('#monthly_saved').innerText.includes('Scénario 1')`);
  const saved = await c.evaluate(`document.getElementById('monthly_saved').innerText`);
  assert(saved.includes('16\u202f500') && saved.includes('200,0 h/mois'), 'Hypothèses conservées divergentes');
  observations.push({case:'hypotheses-conservees', text:saved});
  await value('maint_h', 200); await check(16500);
  await value('ps', 80);
  await settled(`Number(document.getElementById('monthly-unit-current')?.dataset.value) === 15.625`);
  observations.push({case:'acceptation-80pct', ...await state()});
  await value('ps', 100); await value('amort_months', 12); await check(18000);
  await c.evaluate(`document.querySelector('#projection_months').closest('details').open = true`);
  await settled(`document.querySelector('#plot_roi')?.data?.some(t => t.y?.includes(126000))`);
  const projection6 = await c.evaluate(`document.querySelector('#plot_roi').data.map(t => ({x:t.x,y:t.y,name:t.name}))`);
  observations.push({case:'projection-6mois-repartition12', traces:projection6});
  await value('projection_months', 12);
  await settled(`document.querySelector('#plot_roi')?.data?.some(t => t.y?.includes(432000))`);
  observations.push({case:'projection-12mois', traces:await c.evaluate(`document.querySelector('#plot_roi').data.map(t => ({x:t.x,y:t.y,name:t.name}))`)});
  await value('ps', 0);
  await settled(`document.getElementById('monthly_summary').innerText.includes('Aucun résultat') && document.getElementById('monthly-ratio-unavailable').getClientRects().length > 0`);
  observations.push({case:'acceptation-nulle', text:await c.evaluate(`document.getElementById('monthly_summary').innerText`)});
  await value('vol', 0);
  await settled(`document.getElementById('monthly_summary').innerText.includes('Vérifiez les paramètres')`);
  observations.push({case:'volume-invalide', text:await c.evaluate(`document.getElementById('monthly_summary').innerText`)});
  await c.evaluate(`document.getElementById('load_monthly_example').click()`); await check(16500);
  // Contrôle à une largeur de portable, puis de téléphone ; pas d'export PDF.
  const layouts = [];
  for (const width of [1280, 390]) {
    await c.call('Emulation.setDeviceMetricsOverride', {width, height:1000, deviceScaleFactor:1, mobile:false});
    await c.evaluate(`window.dispatchEvent(new Event('resize'))`);
    await c.evaluate(`new Promise(resolve => setTimeout(resolve, 700))`);
    await settled(`document.getElementById('monthly-analytical')?.dataset.value === '16500'`);
    const layout = await c.evaluate(`({width:innerWidth, documentWidth:document.documentElement.scrollWidth, summaryWidth:document.getElementById('monthly-result-card').getBoundingClientRect().width})`);
    assert(layout.summaryWidth <= width && layout.documentWidth <= width, 'Débordement de la mise en page');
    layouts.push(layout);
    const shot = await c.call('Page.captureScreenshot', {format:'png', captureBeyondViewport:false});
    writeFileSync(dir+`capture-${width}.png`, Buffer.from(shot.data,'base64'));
  }
  // Les six onglets publics doivent fonctionner sans dépendance aux pages internes.
  const tabs = await c.evaluate(`[...document.querySelectorAll('a.nav-link[data-bs-toggle="tab"]')].map(e=>e.textContent.trim())`);
  const expectedTabs = ['Manuel vs Agentique','C1 - Inférence','C2 - Infra','C3 - Humain',"Diagnostic d'Investissement (CTP)",'Prix API'];
  assert(JSON.stringify(tabs) === JSON.stringify(expectedTabs), 'Navigation publique divergente');
  await c.call('Emulation.setDeviceMetricsOverride', {width:1440,height:1400,deviceScaleFactor:1,mobile:false});
  const outputs = {'C1 - Inférence':'plot_c1_compare','C2 - Infra':'c2_budget','C3 - Humain':'c3_summary',"Diagnostic d'Investissement (CTP)":'ctp_summary','Prix API':'table_pricing_edit'};
  for (const [label,id] of Object.entries(outputs)) {
    await c.evaluate(`Array.from(document.querySelectorAll('a.nav-link')).find(e=>e.textContent.trim()===${JSON.stringify(label)}).click()`);
    await settled(`document.getElementById(${JSON.stringify(id)})?.innerHTML.length > 0`);
    const errors = await c.evaluate(`[...document.querySelectorAll('.tab-pane.active .shiny-output-error')].map(e=>e.textContent)`);
    assert(!errors.length, `Erreur dans ${label}: ${errors.join('; ')}`);
    observations.push({case:'onglet-public',label,output:id,errors});
  }
  const files = ['app.R','R/ui.R','R/server.R','R/logic_maths.R','R/logic_monthly.R','data/scenarios/veille-section-1.json'];
  const report = {date:new Date().toISOString(), app, base_commit:execFileSync('git',['-C',app,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),
    source_sha256:Object.fromEntries(files.map(f=>[f,createHash('sha256').update(readFileSync(`${app}/${f}`)).digest('hex')])),
    browser:await c.call('Browser.getVersion'), capture_viewport:{width:1440,height:1400,deviceScaleFactor:1}, crop:rect, observations, layouts};
  writeFileSync(dir+'scenario.json', JSON.stringify(scenario,null,2)+'\n');
  writeFileSync(dir+'verification-interface.json', JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({checks:observations.length, layouts, status:'OK'}));
} finally {c.close();}
