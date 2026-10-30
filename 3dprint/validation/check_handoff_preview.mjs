import {chromium} from '/Users/mk10/.cache/codex/rack-viewer/node_modules/playwright/index.mjs';
import fs from 'node:fs';
const root='/Users/mk10/Desktop/hide_player_flutter/3dprint';
const params=JSON.parse(fs.readFileSync(root+'/parameters.json','utf8'));
const b=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const p=await b.newPage({viewport:{width:1380,height:1050},deviceScaleFactor:1});const errors=[];p.on('pageerror',e=>errors.push(String(e)));const pages=[];
for(const file of ['print-handoff.html','parameter-audit.html']){
 await p.goto('file://'+root+'/'+file);await p.waitForLoadState('load');
 await p.screenshot({path:root+'/validation/'+file.replace('.html','')+'-desktop.png',fullPage:true});
 const localLinks=await p.locator('a[href]').evaluateAll(as=>as.map(a=>a.getAttribute('href')).filter(h=>!h.startsWith('http')&&!h.startsWith('#')));
 const missing=localLinks.filter(h=>!fs.existsSync(root+'/'+h));
 await p.setViewportSize({width:390,height:844});
 await p.screenshot({path:root+'/validation/'+file.replace('.html','')+'-mobile.png',fullPage:true});
 const mobileOverflow=await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 pages.push({file,missingLocalLinks:missing,mobileOverflow});await p.setViewportSize({width:1380,height:1050});
}
await p.locator('#piA').fill('98.5');await p.locator('#piB').fill('67');await p.locator('#piC').fill('31');await p.locator('#format').click();
const t=await p.locator('#measure-result').inputValue();const measurementFormPassed=t.includes('98.5 mm')&&t.includes('\n硬盘');
await p.reload();await p.locator('#measure').screenshot({path:root+'/validation/case-measurement.png'});
const report={revision:params.revision,errors,pages,measurementFormPassed};fs.writeFileSync(root+'/validation/handoff-preview-check.json',JSON.stringify(report,null,2));console.log(report);await b.close();if(errors.length||pages.some(v=>v.missingLocalLinks.length||v.mobileOverflow)||!measurementFormPassed)process.exit(1);
