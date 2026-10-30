import {chromium} from '/Users/mk10/.cache/codex/rack-viewer/node_modules/playwright/index.mjs';
import fs from 'node:fs';import {fileURLToPath} from 'node:url';
const R=fileURLToPath(new URL('..',import.meta.url));
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1600,height:1300},deviceScaleFactor:1});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
await page.goto(new URL('makerworld-v0.3.2.html',import.meta.url).href);await page.waitForFunction(()=>window.previewReady,{timeout:60000});const report=[];
for(const [mode,file] of [['front-structure','01-cover-structure'],['front-equipped','02-front-equipped'],['rear','03-rear-open'],['inside','04-inside-pi-dtx']]){
 const state=await page.evaluate(m=>window.makerworldRender.setView(m),mode);
 await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
 const dest=R+'/makerworld_upload/images/'+file;
 await page.locator('#sheet').screenshot({path:dest+'.png'});
 await page.locator('#sheet').screenshot({path:dest+'.jpg',type:'jpeg',quality:93});
 report.push({...state,png:'makerworld_upload/images/'+file+'.png',jpg:'makerworld_upload/images/'+file+'.jpg',width:1600,height:1200,cadGeometryUnchanged:true,realPrintPhoto:false});
}
await browser.close();fs.writeFileSync(R+'/validation/makerworld-image-report.json',JSON.stringify({errors,images:report},null,2));console.log({errors,images:report.length});if(errors.length)process.exit(1);
