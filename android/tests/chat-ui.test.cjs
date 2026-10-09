const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(process.env.HFIT_PLAYWRIGHT_MODULE||'playwright');
const C=require('../assets/core.js');const assets=path.resolve(__dirname,'../assets');
const allowed=['index.html','app.css','catalog.js','core.js','onboarding.js','chat.js','app.js','icon.png'];
const server=http.createServer((req,res)=>{const file=req.url==='/'?'index.html':req.url.slice(1);if(!allowed.includes(file)){res.writeHead(404);res.end();return;}res.setHeader('Content-Type',file.endsWith('.css')?'text/css':file.endsWith('.js')?'application/javascript':file.endsWith('.png')?'image/png':'text/html');res.end(fs.readFileSync(path.join(assets,file)));});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
 try{
  browser=await chromium.launch({executablePath:process.env.HFIT_CHROME_PATH,headless:true});const page=await browser.newPage({viewport:{width:390,height:844}}),errors=[],requests=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>requests.push(r.url()));
  const initial=C.completeSetup(C.initial(),{name:'Alex',age:'25',height:'',weight:'',goal:'balance',activity:'moderate'});delete initial.chat;delete initial.chatDraft;
  await page.addInitScript(s=>{if(!localStorage.getItem('hfit-test'))localStorage.setItem('hfit-test',JSON.stringify(s));window.HFitNative={load:()=>localStorage.getItem('hfit-test')||'',save:s=>{if(window.failSave)return false;localStorage.setItem('hfit-test',s);return true;}};},initial);
  await page.goto('http://127.0.0.1:'+server.address().port);await page.getByRole('button',{name:'Chat',exact:true}).click();
  assert.equal(await page.getByText('KI noch nicht verbunden',{exact:true}).count(),1);assert.equal(await page.getByRole('button',{name:'Frage vormerken',exact:true}).isDisabled(),true);
  await page.locator('#chat-input').fill('Mein erster Entwurf');await page.waitForFunction(()=>state.chatDraft==='Mein erster Entwurf');await page.reload();await page.getByRole('button',{name:'Chat',exact:true}).click();assert.equal(await page.locator('#chat-input').inputValue(),'Mein erster Entwurf');
  await page.getByRole('button',{name:'Was könnte ich heute proteinreich essen?',exact:true}).click();await page.getByRole('button',{name:'Abbrechen',exact:true}).click();assert.equal(await page.locator('#chat-input').inputValue(),'Mein erster Entwurf');
  await page.evaluate(()=>window.failSave=true);await page.getByRole('button',{name:'Frage vormerken',exact:true}).click();assert.equal(await page.evaluate(()=>state.chat.length),0);assert.equal(await page.locator('#chat-input').inputValue(),'Mein erster Entwurf');
  await page.evaluate(()=>window.failSave=false);await page.getByRole('button',{name:'Frage vormerken',exact:true}).click();assert.equal(await page.evaluate(()=>state.chat.length),1);assert.equal(await page.evaluate(()=>state.chatDraft),'');
  await page.getByRole('button',{name:'Frage bearbeiten',exact:true}).click();await page.locator('#chat-edit').fill('Wie kann ich mein Training planen?');await page.getByRole('button',{name:'Änderung speichern',exact:true}).click();assert.equal(await page.evaluate(()=>state.chat[0].text),'Wie kann ich mein Training planen?');
  await page.locator('#chat-input').fill('<img src=x onerror="window.injected=true">');await page.getByRole('button',{name:'Frage vormerken',exact:true}).click();assert.equal(await page.locator('.chat-bubble img').count(),0);assert.equal(await page.evaluate(()=>window.injected),undefined);
  await page.reload();await page.getByRole('button',{name:'Chat',exact:true}).click();assert.equal(await page.locator('.chat-message').count(),2);
  await page.getByRole('button',{name:'Frage bearbeiten',exact:true}).last().click();await page.getByRole('button',{name:'Frage löschen',exact:true}).click();await page.getByRole('button',{name:'Löschen',exact:true}).click();assert.equal(await page.locator('.chat-message').count(),1);
  const shots=path.resolve(__dirname,'../build/qa');fs.mkdirSync(shots,{recursive:true});await page.screenshot({path:path.join(shots,'chat.png'),fullPage:true});
  await page.locator('#chat-input').fill('Behalten');await page.waitForFunction(()=>state.chatDraft==='Behalten');await page.getByRole('button',{name:'Verlauf löschen',exact:true}).click();await page.getByRole('button',{name:'Abbrechen',exact:true}).click();assert.equal(await page.evaluate(()=>state.chat.length),1);
  await page.getByRole('button',{name:'Verlauf löschen',exact:true}).click();await page.locator('dialog').getByRole('button',{name:'Verlauf löschen',exact:true}).click();assert.equal(await page.evaluate(()=>state.chat.length),0);assert.equal(await page.locator('#chat-input').inputValue(),'Behalten');
  await page.getByRole('button',{name:'Verbindungsstatus ansehen',exact:true}).click();assert.equal(await page.getByText('Die KI-Anbindung kommt später.',{exact:true}).count(),1);await page.getByRole('button',{name:'Verstanden',exact:true}).click();
  for(const width of [320,800]){await page.setViewportSize({width,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);}
  assert.equal(requests.some(u=>!u.startsWith('http://127.0.0.1:')),false);assert.deepEqual(errors,[]);console.log('PASS: chat migration, status, draft persistence, save failure, queue/edit/delete/clear, restart, HTML escaping, responsive layout and no external requests.');
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
