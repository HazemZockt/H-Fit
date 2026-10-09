const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const {chromium}=require(process.env.HFIT_PLAYWRIGHT_MODULE||'playwright');
const assets=path.resolve(__dirname,'../assets');
const server=http.createServer((req,res)=>{
  const filename=req.url==='/'?'index.html':req.url.slice(1);
  if(!['index.html','app.css','catalog.js','core.js','onboarding.js','chat.js','app.js','icon.png'].includes(filename)){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',filename.endsWith('.css')?'text/css':filename.endsWith('.js')?'application/javascript':filename.endsWith('.png')?'image/png':'text/html');
  res.end(fs.readFileSync(path.join(assets,filename)));
});
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 let browser;
 try{
  browser=await chromium.launch({executablePath:process.env.HFIT_CHROME_PATH,headless:true});
  const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.HFitNative={load:()=>localStorage.getItem('hfit-test')||'',save:s=>{localStorage.setItem('hfit-test',s);return true;},steps:()=>window.NativeEvents('steps',{message:'Kein Schrittsensor im Emulator.'}),speak:()=>window.NativeEvents('speech',{message:'zwei Eier'}),lookup:code=>window.NativeEvents('product',{status:1,barcode:code,product:{product_name:'Testprodukt',nutriments:{'energy-kcal_100g':200,'proteins_100g':10,'carbohydrates_100g':20,'fat_100g':8}}}),exportBackup:()=>{},importBackup:()=>{}};});
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.locator('#setup-name').fill('Alex');
  await page.locator('#setup-age').fill('25');
  await page.getByRole('button',{name:'Weiter',exact:true}).click();
  await page.getByRole('button',{name:'Weiter',exact:true}).click();
  await page.locator('input[name="setup-activity"][value="moderate"]').check();
  await page.getByRole('button',{name:'Los geht’s',exact:true}).click();
  await page.getByRole('button',{name:'Was hast du gegessen?'}).click();
  await page.getByRole('button',{name:'Beispiel einsetzen'}).click();
  await page.getByRole('button',{name:'Erkennen',exact:true}).click();
  assert.equal(await page.locator('.draft').count(),3);
  await page.getByRole('button',{name:'3 Einträge speichern'}).click();
  assert.equal(await page.locator('.number').textContent(),'424');
  await page.reload();assert.equal(await page.locator('.number').textContent(),'424');
  await page.locator('.meal').first().click();await page.locator('#edit-amount').fill('80');await page.getByRole('button',{name:'Speichern',exact:true}).click();
  assert.equal(await page.locator('.number').textContent(),'498');
  await page.getByRole('button',{name:'+ 250 ml',exact:true}).click();
  assert.equal(await page.evaluate(()=>state.water[0].amount),250);
  const shots=path.resolve(__dirname,'../build/qa');fs.mkdirSync(shots,{recursive:true});
  await page.screenshot({path:path.join(shots,'today.png'),fullPage:true});
  await page.getByRole('button',{name:'Was hast du gegessen?'}).click();await page.locator('#meal-text').fill('250 g Zauberkuchen');await page.getByRole('button',{name:'Erkennen',exact:true}).click();
  await page.getByRole('button',{name:'1 Einträge speichern'}).click();assert.equal(await page.evaluate(()=>state.meals.length),3);assert.equal(await page.locator('dialog[open]').count(),1);
  await page.getByRole('button',{name:'Schließen',exact:true}).click();
  await page.getByRole('button',{name:'Bewegung',exact:true}).click();await page.getByRole('button',{name:'Manuell',exact:true}).click();await page.locator('#entry-number').fill('4000');await page.getByRole('button',{name:'Speichern',exact:true}).click();assert.equal(await page.evaluate(()=>stepCount()),4000);
  await page.getByRole('button',{name:'Verlauf',exact:true}).click();await page.getByRole('button',{name:'+ Eintragen',exact:true}).click();await page.locator('#entry-number').fill('75,5');await page.getByRole('button',{name:'Speichern',exact:true}).click();assert.equal(await page.evaluate(()=>state.weights[0].value),75.5);
  await page.getByRole('button',{name:'Mein Plan',exact:true}).click();await page.getByRole('button',{name:'Richtwerte bearbeiten',exact:true}).click();await page.locator('#target-k').fill('2400');await page.getByRole('button',{name:'Richtwerte speichern'}).click();assert.equal(await page.evaluate(()=>state.profile.kcal),2400);
  await page.getByRole('button',{name:'Eigene Rezepte & Mahlzeiten',exact:true}).click();await page.getByRole('button',{name:'+ Eigenes Rezept'}).click();await page.locator('#recipe-name').fill('Mein Frühstück');await page.getByRole('button',{name:'+ Zutat hinzufügen'}).click();await page.locator('#food-search').fill('Haferflocken');await page.getByRole('button',{name:/Haferflocken/}).click();await page.locator('[data-ingredient]').fill('100');await page.getByRole('button',{name:'Rezept speichern'}).click();assert.equal(await page.evaluate(()=>state.recipes[0].ingredients[0].amount),100);
  await page.getByRole('button',{name:/Mein Frühstück/}).click();await page.locator('#eat-portions').fill('1');await page.getByRole('button',{name:'Eintragen',exact:true}).click();assert.equal(await page.evaluate(()=>state.meals.at(-1).amount),50);
  await page.getByRole('button',{name:'Heute',exact:true}).click();await page.getByRole('button',{name:'Was hast du gegessen?'}).click();await page.getByRole('button',{name:'Barcode suchen',exact:true}).click();await page.locator('#barcode').fill('12345678');await page.getByRole('button',{name:'Produkt suchen',exact:true}).click();await page.getByRole('button',{name:'Produkt übernehmen'}).click();await page.getByRole('button',{name:'1 Einträge speichern'}).click();assert.equal(await page.evaluate(()=>state.foods[0].name),'Testprodukt');
  await page.reload();assert.equal(await page.evaluate(()=>state.meals.length),5);assert.equal(await page.evaluate(()=>state.recipes.length),1);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
  await page.setViewportSize({width:800,height:1000});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
  await page.screenshot({path:path.join(shots,'tablet.png'),fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('PASS: 14 browser flows: entry, persistence, edit, water, unknown-food guard, steps, weight, profile, recipe creation/scaling, barcode fixture, reload, mobile/tablet overflow. No JavaScript runtime errors. Native Android services are mocked.');
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
