import {chromium} from '/Users/mk10/.cache/codex/rack-viewer/node_modules/playwright/index.mjs';
import {fileURLToPath} from 'node:url';
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1300,height:1300},deviceScaleFactor:1.5});
await page.goto(new URL('../preview.html',import.meta.url).href);
await page.waitForFunction(()=>window.rackViewer);
await page.addStyleTag({content:'.layout{display:block}.viewport{width:1300px;height:1200px;min-height:1200px}.sidebar{display:none}'});
for(const mode of ['front','rear','inside']){
 await page.evaluate(mode=>{window.rackViewer.controls.enableDamping=false;window.rackViewer.view(mode);},mode);
 await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
 const rev=await page.evaluate(()=>window.rackViewer.data.parameters.revision.split('-')[0]);
 await page.locator('#view').screenshot({path:fileURLToPath(new URL(`cad-${rev}-${mode}-reference.png`,import.meta.url))});
}
await browser.close();
