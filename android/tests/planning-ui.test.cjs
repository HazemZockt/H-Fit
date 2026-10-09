const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(process.env.HFIT_PLAYWRIGHT_MODULE||'playwright');
const assets=path.resolve(__dirname,'../assets'),allowed=['index.html','app.css','catalog.js','core.js','onboarding.js','chat.js','app.js','icon.png'];
const server=http.createServer((req,res)=>{const f=req.url==='/'?'index.html':req.url.slice(1);if(!allowed.includes(f)){res.writeHead(404);res.end();return;}res.setHeader('Content-Type',f.endsWith('.css')?'text/css':f.endsWith('.js')?'application/javascript':f.endsWith('.png')?'image/png':'text/html');res.end(fs.readFileSync(path.join(assets,f)));});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
 try{
  browser=await chromium.launch({executablePath:process.env.HFIT_CHROME_PATH,headless:true});const page=await browser.newPage({viewport:{width:390,height:844}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.HFitNative={load:()=>localStorage.getItem('hfit-plan')||'',save:s=>{localStorage.setItem('hfit-plan',s);return true;}};});
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.locator('#setup-name').fill('Alex');await page.locator('#setup-age').fill('30');await page.getByRole('button',{name:'Weiter',exact:true}).click();
  await page.locator('#setup-height').fill('180');await page.locator('#setup-weight').fill('80');await page.locator('#setup-sex').selectOption('male');await page.getByRole('button',{name:'Weiter',exact:true}).click();
  await page.locator('[name="setup-activity"][value="moderate"]').check();assert.match(await page.locator('#setup-plan').textContent(),/2.670/);
  await page.locator('[name="setup-goal"][value="lose"]').check();assert.match(await page.locator('#setup-plan').textContent(),/2.400/);
  await page.locator('[name="setup-goal"][value="balance"]').check();await page.getByRole('button',{name:'Los geht’s',exact:true}).click();
  assert.match(await page.locator('.summary').textContent(),/2.670/);
  await page.locator('[data-act="capture"]').click();await page.locator('#meal-text').fill('100 g Haferflocken');await page.getByRole('button',{name:'Erkennen',exact:true}).click();
  assert.match(await page.locator('#draft-total').textContent(),/372 kcal/);await page.locator('[data-amount]').fill('50');assert.match(await page.locator('[data-energy]').textContent(),/186 kcal/);assert.match(await page.locator('#draft-total').textContent(),/186 kcal/);
  await page.getByRole('button',{name:'1 Einträge speichern',exact:true}).click();assert.equal(await page.locator('.summary .number').textContent(),'186');assert.match(await page.locator('.summary').textContent(),/2.484 kcal offen/);
  await page.getByRole('button',{name:'Chat',exact:true}).click();await page.locator('#chat-input').fill('Wie ist meine Bilanz heute?');await page.getByRole('button',{name:'Lokal auswerten',exact:true}).click();assert.match(await page.locator('.chat-message .card').textContent(),/186 kcal/);
  await page.reload();await page.getByRole('button',{name:'Chat',exact:true}).click();assert.match(await page.locator('.chat-message .card').textContent(),/186 kcal/);
  const shots=path.resolve(__dirname,'../build/qa');fs.mkdirSync(shots,{recursive:true});await page.screenshot({path:path.join(shots,'assistant-1.3.png'),fullPage:true});
  await page.getByRole('button',{name:'Heute',exact:true}).click();await page.screenshot({path:path.join(shots,'today-1.3.png'),fullPage:true});
  await page.getByRole('button',{name:'Verlauf',exact:true}).click();await page.getByRole('button',{name:'Monat',exact:true}).click();
  assert.equal(await page.locator('.calendar-day').count(),new Date(new Date().getFullYear(),new Date().getMonth()+1,0).getDate());
  assert.equal(await page.locator('.ring-value').count(),0);await page.locator('#complete-day').check();assert.equal(await page.locator('.ring-value').count(),1);
  await page.screenshot({path:path.join(shots,'month-1.4.png'),fullPage:true});
  await page.getByRole('button',{name:'Vorheriger Monat',exact:true}).click();assert.equal(await page.locator('.ring-value').count(),0);
  await page.getByRole('button',{name:'Nächster Monat',exact:true}).click();assert.equal(await page.locator('.ring-value').count(),1);
  for(const width of [320,390]){await page.setViewportSize({width,height:844});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);}
  await page.reload();await page.getByRole('button',{name:'Verlauf',exact:true}).click();await page.getByRole('button',{name:'Monat',exact:true}).click();assert.equal(await page.locator('.ring-value').count(),1);
  await page.locator('#complete-day').uncheck();assert.equal(await page.locator('.ring-value').count(),0);await page.getByRole('button',{name:'Woche',exact:true}).click();assert.equal(await page.locator('.bars').count(),1);
  await page.getByRole('button',{name:'Mein Plan',exact:true}).click();await page.getByRole('button',{name:'Profil bearbeiten',exact:true}).click();await page.getByRole('button',{name:'Weiter',exact:true}).click();await page.getByRole('button',{name:'Weiter',exact:true}).click();
  await page.screenshot({path:path.join(shots,'setup-1.3.png'),fullPage:true});
  for(const width of [320,800]){await page.setViewportSize({width,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);}
  assert.deepEqual(errors,[]);console.log('PASS: automatic setup preview, 2670/2400 targets, live portion recalculation, daily remainder, computed assistant response, reload and responsive layout.');
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
