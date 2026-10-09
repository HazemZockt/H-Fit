'use strict';
let setupDraft=null,setupStep=0,setupEditing=false;
const activityLabels={low:'Überwiegend sitzend',moderate:'Regelmäßig in Bewegung',high:'Viel in Bewegung'};
function startSetup(){close();setupEditing=true;setupDraft=null;setupStep=0;render();window.scrollTo(0,0);}
function setupRead(){
  if(setupStep===0){setupDraft.name=$('setup-name').value;setupDraft.age=$('setup-age').value;}
  else if(setupStep===1){setupDraft.height=$('setup-height').value;setupDraft.weight=$('setup-weight').value;setupDraft.sex=$('setup-sex')?.value??'unspecified';}
  else{setupDraft.goal=document.querySelector('[name="setup-goal"]:checked')?.value??(C.number(setupDraft.age)<18?'balance':'');setupDraft.activity=document.querySelector('[name="setup-activity"]:checked')?.value??'';setupDraft.automatic=$('setup-auto')?.checked??false;}
}
function setupCheck(){
  if(setupStep===0){if(!setupDraft.name.trim())throw Error('Wie dürfen wir dich nennen? Ein Spitzname reicht.');const age=C.number(setupDraft.age);if(!Number.isInteger(age)||!C.finite(age,1,120))throw Error('Bitte dein Alter als ganze Zahl zwischen 1 und 120 eingeben.');}
  if(setupStep===1){if(setupDraft.height!==''&&!C.finite(C.number(setupDraft.height),80,250))throw Error('Bitte die Größe in cm prüfen (80–250), oder das Feld leer lassen.');if(setupDraft.weight!==''&&!C.finite(C.number(setupDraft.weight),20,500))throw Error('Bitte das Gewicht in kg prüfen (20–500), oder das Feld leer lassen.');}
}
function setupBack(){setupRead();if(setupStep>0){setupStep--;renderSetup();window.scrollTo(0,0);}else if(setupEditing){setupEditing=false;setupDraft=null;render();}}
function renderSetup(){
  if(!setupDraft){const p=state.profile;setupDraft={name:p.name,age:p.age??'',height:p.height??'',weight:C.currentWeight(state)??'',goal:p.goal,activity:p.activity??'',sex:p.sex??'unspecified',automatic:p.automatic??true};}
  const adult=C.number(setupDraft.age)>=18;
  const choice=(group,value,title,description,checked)=>`<label class="setup-choice"><input type="radio" name="setup-${group}" value="${value}" ${checked?'checked':''}><span><strong>${E(title)}</strong>${description?`<small>${E(description)}</small>`:''}</span></label>`;
  const titles=['Schön, dass du da bist.','Dein Ausgangspunkt.','Was passt zu dir?'];
  const descriptions=['Zwei Angaben, damit H-Fit dich richtig ansprechen kann.','Für dein Profil und deinen Gewichtsverlauf. Du kannst beides auch später ergänzen.','Dein Fokus und dein Alltag. Beides kannst du jederzeit ändern.'];
  let content='';
  if(setupStep===0)content=`${field('Name oder Spitzname','setup-name',setupDraft.name,'text','maxlength="80" autocomplete="given-name" placeholder="Wie dürfen wir dich nennen?"')}${field('Alter in Jahren','setup-age',setupDraft.age,'text','inputmode="numeric" maxlength="3" placeholder="z. B. 25"')}<p class="hint setup-note">Kein Login, keine E-Mail. Deine Angaben bleiben in dieser App auf deinem Gerät.</p>`;
  if(setupStep===1)content=`${field('Größe in cm · optional','setup-height',setupDraft.height,'text','inputmode="decimal" maxlength="6" placeholder="z. B. 175"')}${field('Aktuelles Gewicht in kg · optional','setup-weight',setupDraft.weight,'text','inputmode="decimal" maxlength="7" placeholder="z. B. 75,5"')}${adult?`<label class="label" for="setup-sex">Formel für den Energiebedarf</label><select id="setup-sex"><option value="unspecified">Keine Angabe</option><option value="female" ${setupDraft.sex==='female'?'selected':''}>Weiblich</option><option value="male" ${setupDraft.sex==='male'?'selected':''}>Männlich</option></select><p class="hint">Die veröffentlichte Formel unterscheidet weiblich und männlich. Ohne Auswahl kein automatisches Ziel.</p>`:''}<p class="hint setup-note">Dein erstes Gewicht erscheint automatisch im Verlauf. Es gibt hier kein vorgeschriebenes Wunschgewicht.</p>`;
  if(setupStep===2)content=`<fieldset class="setup-group"><legend>Dein Ziel</legend>${adult?`<div class="setup-goals">${choice('goal','balance','Fit bleiben','',setupDraft.goal==='balance')}${choice('goal','lose','Abnehmen','',setupDraft.goal==='lose')}${choice('goal','build','Muskeln aufbauen','',setupDraft.goal==='build')}</div>`:'<p class="setup-young">Fit bleiben und Freude an Bewegung finden. Für unter 18-Jährige richtet H-Fit keine Abnehm- oder Kalorienziele ein.</p>'}</fieldset><fieldset class="setup-group"><legend>Wie bewegst du dich im Alltag?</legend>${choice('activity','low',activityLabels.low,'Meist Schreibtisch, Schule oder Studium',setupDraft.activity==='low')}${choice('activity','moderate',activityLabels.moderate,'Oft zu Fuß und regelmäßig aktiv',setupDraft.activity==='moderate')}${choice('activity','high',activityLabels.high,'Viel auf den Beinen oder körperliche Arbeit',setupDraft.activity==='high')}</fieldset>${adult?`<label class="setup-choice"><input type="checkbox" id="setup-auto" ${setupDraft.automatic?'checked':''}><span><strong>Kalorien und Makros berechnen</strong><small>Für gesunde Erwachsene. Bei Schwangerschaft, Stillzeit oder besonderen Ernährungsanforderungen ausschalten und fachlich abgestimmte Richtwerte nutzen.</small></span></label>`:''}<div id="setup-plan" class="card">${setupPlanPreview()}</div>`;
  $('app').innerHTML=`<main class="setup"><header class="head"><div class="brand">H<b>·</b>FIT</div>${setupEditing?'<button class="quiet small" data-setup="cancel">Abbrechen</button>':'<span class="tag">GANZ OHNE KONTO</span>'}</header><div class="setup-progress" role="progressbar" aria-label="Einrichtung" aria-valuemin="1" aria-valuemax="3" aria-valuenow="${setupStep+1}">${[0,1,2].map(i=>`<span class="${i<=setupStep?'done':''}"></span>`).join('')}</div><p class="eyebrow">SCHRITT ${setupStep+1} VON 3 · ETWA 1 MINUTE</p><h1 id="setup-title" tabindex="-1">${titles[setupStep]}</h1><p class="muted setup-intro">${descriptions[setupStep]}</p><div class="setup-fields">${content}</div><p id="setup-error" class="error" role="alert" hidden></p><footer class="setup-footer"><div class="actions">${setupStep>0?'<button data-setup="back">Zurück</button>':''}<button class="primary" data-setup="next">${setupStep===2?(setupEditing?'Änderungen speichern':'Los geht’s'):'Weiter'}</button></div><small>Jederzeit unter „Mein Plan“ anpassbar.</small>${!setupEditing&&setupStep===0?'<button class="quiet small" data-act="import">Vorhandene Sicherung wiederherstellen</button>':''}</footer></main>`;
}
document.addEventListener('click',event=>{
  const button=event.target.closest('[data-setup]');if(!button)return;
  try{
    if(button.dataset.setup==='cancel'){setupEditing=false;setupDraft=null;render();return;}
    if(button.dataset.setup==='back'){setupBack();return;}
    setupRead();setupCheck();
    if(setupStep<2){setupStep++;renderSetup();window.scrollTo(0,0);$('setup-title').focus({preventScroll:true});return;}
    const completed=C.completeSetup(state,setupDraft),wasEditing=setupEditing;
    setupEditing=false;
    if(save(next=>Object.assign(next,completed))){setupDraft=null;setupStep=0;window.scrollTo(0,0);toast(wasEditing?'Profil aktualisiert.':'Willkommen bei H-Fit, '+completed.profile.name+'!');}
    else{setupEditing=wasEditing;render();}
  }catch(error){$('setup-error').textContent=error.message;$('setup-error').hidden=false;$('setup-error').scrollIntoView({block:'nearest',behavior:'smooth'});}
});

for(const eventName of ['input','change'])document.addEventListener(eventName,event=>{if(event.target.closest('.setup')&&$('setup-error'))$('setup-error').hidden=true;});

function setupPlanPreview(){
 const p={...setupDraft,age:C.number(setupDraft.age),height:C.number(setupDraft.height),weight:C.number(setupDraft.weight),adult:C.number(setupDraft.age)>=18};
 const plan=C.plan(p);
 return plan?`<div class="eyebrow">DEIN STARTPUNKT</div><h2>≈ ${fmt(plan.kcal)} kcal / Tag</h2><p>${fmt(plan.protein)} g Eiweiß · ${fmt(plan.carbs)} g Kohlenhydrate · ${fmt(plan.fat)} g Fett</p><p class="hint">Eine Schätzung, kein gemessener Bedarf. Deine Aktivität ist bereits enthalten. Neue Gewichtseinträge aktualisieren den Richtwert.</p>`:'<p class="hint">Kein automatischer Richtwert: Dafür werden Alter ab 18, Größe, Gewicht, Formel-Auswahl und Alltagsbewegung benötigt. Bei Untergewicht oder ausgeschalteter Berechnung bleibt dein Tagebuch ohne Ziel nutzbar.</p>';
}
document.addEventListener('change',event=>{if(setupStep===2&&event.target.closest('.setup')&&$('setup-plan')){setupRead();$('setup-plan').innerHTML=setupPlanPreview();}});
