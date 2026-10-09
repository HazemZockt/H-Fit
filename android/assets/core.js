(function (root) {
  'use strict';
  const finite = (n, min = 0, max = 10000) => typeof n === 'number' && Number.isFinite(n) && n >= min && n <= max;
  const uid = () => typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  const dayKey = (date = new Date()) => `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
  const dateValid = x => typeof x === 'string' && Number.isFinite(new Date(x).getTime()) && new Date(x).getFullYear() >= 1900 && new Date(x).getFullYear() <= 2100;
  const number = x => { const s = String(x).trim().replace(',', '.'); return s !== '' ? Number(s) : NaN; };
  const escape = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const foodValid = f => f && typeof f.id === 'string' && f.id.length <= 150 && typeof f.name === 'string' && f.name.trim().length > 0 && f.name.length <= 120 && ['g','ml'].includes(f.unit) && finite(f.portion, .01, 5000) && ['k','p','c','f'].every(k => finite(f[k], 0, 1000)) && Array.isArray(f.aliases) && f.aliases.length <= 30 && f.aliases.every(a => typeof a === 'string' && a.length > 0 && a.length <= 120);
  const nutrients = (food, amount) => ({k:food.k*amount/100,p:food.p*amount/100,c:food.c*amount/100,f:food.f*amount/100});
  const totals = meals => meals.reduce((sum, m) => { const n = nutrients(m.food,m.amount); for (const k of ['k','p','c','f']) sum[k] += n[k]; return sum; }, {k:0,p:0,c:0,f:0});
  const initial = () => ({format:'hfit-android-1',setupComplete:false, profile:{name:'',age:null,height:null,weight:null,activity:null,adult:false,goal:'balance',kcal:0,protein:0},meals:[],foods:[],water:[],weights:[],workouts:[],steps:[],recipes:[],chat:[],chatDraft:'',fastStart:null});
  const migrate = s => ({...s,chat:s.chat??[],chatDraft:s.chatDraft??'',setupComplete:s.setupComplete??false,profile:{age:null,height:null,weight:null,activity:null,...s.profile}});
  function queueQuestion(s,text,now=new Date()) {
    const trimmed=String(text).trim();
    if(!trimmed||trimmed.length>2000)throw Error('Bitte eine Frage mit höchstens 2.000 Zeichen schreiben.');
    if(s.chat.length>=200)throw Error('Dein Chat enthält bereits 200 Fragen. Lösche ältere Einträge, bevor du neue vormerkst.');
    const next=JSON.parse(JSON.stringify(s));next.chat.push({id:uid(),role:'user',text:trimmed,date:now.toISOString(),status:'queued'});next.chatDraft='';validate(next);return next;
  }
  function completeSetup(s, draft, now=new Date()) {
    const next=JSON.parse(JSON.stringify(s)),name=String(draft.name).trim(),age=number(draft.age);
    const optional=x=>x===null||String(x).trim()===''?null:number(x);
    const height=optional(draft.height),weight=optional(draft.weight);
    if(!name||name.length>80)throw Error('Bitte einen Namen oder Spitznamen eingeben.');
    if(!Number.isInteger(age)||!finite(age,1,120))throw Error('Bitte dein Alter als ganze Zahl zwischen 1 und 120 eingeben.');
    if(height!==null&&!finite(height,80,250))throw Error('Bitte die Größe in cm prüfen (80–250), oder das Feld leer lassen.');
    if(weight!==null&&!finite(weight,20,500))throw Error('Bitte das Gewicht in kg prüfen (20–500), oder das Feld leer lassen.');
    if(!['low','moderate','high'].includes(draft.activity))throw Error('Bitte deine Bewegung im Alltag auswählen.');
    if(age>=18&&!['balance','lose','build'].includes(draft.goal))throw Error('Bitte dein Ziel auswählen.');
    const adult=age>=18;
    next.profile={...next.profile,name,age,height,weight,activity:draft.activity,adult,goal:adult?draft.goal:'balance',sex:draft.sex??s.profile.sex??'unspecified',automatic:adult&&(draft.automatic??s.profile.automatic??false)};
    if(next.profile.automatic){next.profile.kcal=0;next.profile.protein=0;}
    if(!adult){next.profile.kcal=0;next.profile.protein=0;next.fastStart=null;}
    if(weight!==null&&((!s.setupComplete&&s.weights.length===0)||(s.setupComplete&&weight!==currentWeight(s,now))))next.weights.push({id:uid(),value:weight,date:now.toISOString()});
    next.setupComplete=true;validate(next);return next;
  }
  const mealValid = m => m && typeof m.id === 'string' && m.id.length <= 150 && foodValid(m.food) && finite(m.amount,.01,10000) && dateValid(m.date);
  function validate(s) {
    if (!s || s.format !== 'hfit-android-1') throw Error('Das ist keine Sicherung dieser Android-Version. iPhone-Sicherungen haben ein anderes Format.');
    const p=s.profile;
    if (!p || typeof p.name !== 'string' || p.name.length>80 || typeof p.adult!=='boolean' || !['balance','lose','build'].includes(p.goal) || !finite(p.kcal) || !finite(p.protein,0,500)) throw Error('Ungültige Profildaten.');
    if(s.setupComplete!==undefined&&typeof s.setupComplete!=='boolean')throw Error('Ungültiger Einrichtungsstatus.');
    if(s.completedDays!==undefined&&(!Array.isArray(s.completedDays)||s.completedDays.length>10000||new Set(s.completedDays).size!==s.completedDays.length||!s.completedDays.every(d=>typeof d==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(d)&&dateValid(d)&&dayKey(new Date(d+'T12:00:00'))===d)))throw Error('Ungültige abgeschlossene Tage.');
    if(p.age!=null&&(!Number.isInteger(p.age)||!finite(p.age,1,120)))throw Error('Ungültiges Alter.');
    if(p.height!=null&&!finite(p.height,80,250))throw Error('Ungültige Größe.');
    if(p.weight!=null&&!finite(p.weight,20,500))throw Error('Ungültiges Gewicht.');
    if(p.activity!=null&&!['low','moderate','high'].includes(p.activity))throw Error('Ungültige Alltagsbewegung.');
    if(p.sex!=null&&!['unspecified','female','male'].includes(p.sex))throw Error('Ungültige Formel-Auswahl.');
    if(p.automatic!=null&&typeof p.automatic!=='boolean')throw Error('Ungültige Berechnungseinstellung.');
    if(s.setupComplete&&(!p.name.trim()||p.age==null||p.activity==null||p.adult!==(p.age>=18)))throw Error('Das Profil ist noch nicht vollständig eingerichtet.');
    if(s.setupComplete&&!p.adult&&(p.goal!=='balance'||p.kcal!==0||p.protein!==0||s.fastStart!==null))throw Error('Kalorienziele und Essenspausen sind nur für Erwachsene vorgesehen.');
    if(typeof s.chatDraft!=='string'||s.chatDraft.length>2000)throw Error('Ungültiger Chatentwurf.');
    if(!Array.isArray(s.chat)||s.chat.length>200)throw Error('Ungültiger Chatverlauf.');
    const checks = {
      meals: mealValid,
      chat:x=>x.role==='user'&&['queued','local'].includes(x.status)&&typeof x.text==='string'&&x.text.trim().length>0&&x.text.length<=2000&&dateValid(x.date)&&(x.status!=='local'||(typeof x.answer==='string'&&x.answer.length>0&&x.answer.length<=6000)),
      foods: foodValid,
      water:x=>dateValid(x.date)&&finite(x.amount,1,5000),
      weights:x=>dateValid(x.date)&&finite(x.value,20,500),
      workouts:x=>dateValid(x.date)&&typeof x.name==='string'&&x.name.trim().length>0&&x.name.length<=120&&finite(x.minutes,1,1440),
      steps:x=>typeof x.day==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x.day)&&finite(x.count,0,100000),
      recipes:x=>typeof x.name==='string'&&x.name.trim().length>0&&x.name.length<=120&&finite(x.servings,.1,100)&&typeof x.instructions==='string'&&x.instructions.length<=10000&&Array.isArray(x.ingredients)&&x.ingredients.length>0&&x.ingredients.length<=200&&x.ingredients.every(mealValid)
    };
    for (const [key, fn] of Object.entries(checks)) {
      if (!Array.isArray(s[key]) || s[key].length > 20000 || !s[key].every(x=>x&&typeof x.id==='string'&&x.id.length>0&&x.id.length<=150&&fn(x)) || new Set(s[key].map(x=>x.id)).size!==s[key].length) throw Error('Ungültige Daten in: '+key);
    }
    if (s.fastStart!==null && !dateValid(s.fastStart)) throw Error('Ungültiger Timer.');
    return true;
  }
  const regexEscape = s => s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  function parse(text, catalog, now = new Date()) {
    let input = text.toLocaleLowerCase('de-DE'), date = new Date(now);
    const notes = [];
    if (input.includes('vorgestern')) date.setDate(date.getDate()-2);
    else if (input.includes('gestern')) date.setDate(date.getDate()-1);
    const time = /\b(?:um\s+)?(\d{1,2})(?::(\d{2}))?\s*uhr\b|\bum\s+(\d{1,2}):(\d{2})\b/;
    const match = input.match(time);
    if (match) {
      const h=+(match[1]??match[3]), m=+(match[2]??match[4]??0);
      if (h<=23&&m<=59) date.setHours(h,m,0,0); else notes.push('Uhrzeit ungültig. Bitte manuell einstellen.');
    } else if (/frühstück|morgens/.test(input)) date.setHours(8,0,0,0);
    else if (/mittag/.test(input)) date.setHours(12,0,0,0);
    else if (/abend/.test(input)) date.setHours(19,0,0,0);
    if (date > now) { date = new Date(now); notes.push('Die erkannte Uhrzeit lag in der Zukunft. Bitte prüfen.'); }
    input=input.replace(new RegExp(time.source,'g'),' ')
      .replace(/\b(heute|gestern|vorgestern|morgens|mittags|abends|zum frühstück|frühstück|zum mittagessen|mittagessen|zum abendessen|abendessen|ich habe|ich hab|ich|habe|hab|gegessen|getrunken|hatte|noch|dazu)\b/g,' ')
      .replace(/\b(eine?|einen)\s+halbe?[nr]?\b/g,'0.5');
    for (const [word, n] of Object.entries({ein:1,eine:1,einen:1,einem:1,zwei:2,drei:3,vier:4,fünf:5,sechs:6,halb:.5,halbe:.5,halben:.5})) input=input.replace(new RegExp('\\b'+word+'\\b','g'),String(n));
    input=input.replace(/(\d),(?=\d)/g,'$1.').replace(/\s+(und|mit|plus|sowie)\s+|[,;\n+]/g,'|');
    const aliases=catalog.flatMap(food=>[food.name,...food.aliases].map(alias=>({food,alias:alias.toLocaleLowerCase('de-DE')}))).sort((a,b)=>b.alias.length-a.alias.length);
    const items=input.split('|').map(s=>s.trim().replace(/^[.!?\s]+|[.!?\s]+$/g,'')).filter(Boolean).map(segment=>{
      const matches=aliases.filter(x=>new RegExp('(^|[^a-zäöüß])'+regexEscape(x.alias)+'($|[^a-zäöüß])','i').test(segment));
      let food=matches[0]?.food??null;
      if (matches.length && new Set(matches.filter(x=>!matches[0].alias.includes(x.alias)||x.food.id===matches[0].food.id).map(x=>x.food.id)).size>1) food=null;
      const quantity=segment.match(/\b(\d+(?:\.\d+)?)\s*(kilogramm|kg|gramm|g|milliliter|ml|liter|l|el|tl|scheiben?|stücke?|portionen?|becher|glas|gläser)?\b/);
      let amount=food?.portion??100, estimated=true;
      if(quantity){const value=+quantity[1],unit=quantity[2]??'';
        if(['g','gramm','ml','milliliter'].includes(unit)){amount=value;estimated=false;}
        else if(['kg','kilogramm','l','liter'].includes(unit)){amount=value*1000;estimated=false;}
        else if(unit==='el')amount=value*15;
        else if(unit==='tl')amount=value*5;
        else if(['glas','gläser'].includes(unit))amount=value*250;
        else amount=value*(food?.portion??100);
      }
      return {id:uid(),label:segment,food,amount,estimated};
    });
    return {date:date.toISOString(),items,notes};
  }
  function product(response, unit='g') {
    const p=response.product,n=p?.nutriments;
    if(response.status!==1||!p?.product_name||!n)throw Error('Produkt nicht gefunden. Bitte Verpackungsangaben selbst ergänzen.');
    const read=k=>n[k]===null||n[k]===undefined||n[k]===''?NaN:Number(n[k]);
    const kcal=Number.isFinite(read('energy-kcal_100g'))?read('energy-kcal_100g'):read('energy-kj_100g')/4.184;
    const f={id:'off-'+response.barcode,name:String(p.product_name).slice(0,120),aliases:[],k:kcal,p:read('proteins_100g'),c:read('carbohydrates_100g'),f:read('fat_100g'),portion:100,unit};
    if(!foodValid(f))throw Error('Nährwerte fehlen oder sind unplausibel. Bitte von der Verpackung übernehmen.');
    return f;
  }
  function plan(profile,weight=profile.weight){
    const p=profile;
    if(!p.adult||!p.automatic||!finite(p.age,18,120)||!finite(p.height,80,250)||!finite(weight,20,500)||!['female','male'].includes(p.sex)||!['low','moderate','high'].includes(p.activity)||weight/(p.height/100)**2<18.5)return null;
    const resting=10*weight+6.25*p.height-5*p.age+(p.sex==='male'?5:-161),maintenance=resting*{low:1.2,moderate:1.5,high:1.75}[p.activity];
    if(resting<=0)return null;
    const adjustment=p.goal==='lose'?-Math.min(maintenance*.1,300):p.goal==='build'?Math.min(maintenance*.05,200):0;
    const kcal=Math.max(Math.round((maintenance+adjustment)/10)*10,Math.ceil(Math.max(resting,1500)/10)*10),protein=Math.round(Math.min(weight*(p.goal==='build'?1.6:1.2),kcal*.3/4)),fat=Math.round(kcal*.3/9),carbs=Math.round(Math.max(0,(kcal-protein*4-fat*9)/4));
    return {resting,maintenance,kcal,protein,fat,carbs};
  }
  function currentWeight(s,now=new Date()){return s.weights.filter(w=>new Date(w.date)<=now).sort((a,b)=>new Date(b.date)-new Date(a.date))[0]?.value??s.profile.weight;}
  function targets(s,now=new Date()){
    if(!s.profile.adult)return {kcal:0,protein:0};
    return s.profile.automatic?(plan(s.profile,currentWeight(s,now))??{kcal:0,protein:0}):{kcal:s.profile.kcal,protein:s.profile.protein};
  }
  function dayScore(s,date=new Date()){
    const key=dayKey(date),meals=s.meals.filter(x=>dayKey(new Date(x.date))===key),t=targets(s,date);
    if(!(s.completedDays??[]).includes(key)||!meals.length||!s.profile.adult||!t.kcal||!t.protein)return null;
    const n=totals(meals),energy=Math.max(0,1-Math.abs(n.k/t.kcal-1)/.5),protein=Math.min(1,n.p/t.protein);
    return Math.max(0,Math.min(1,.7*energy+.3*protein));
  }
  function waterTotal(s,date=new Date()){
    const key=dayKey(date),onDay=x=>dayKey(new Date(x.date))===key;
    return s.water.filter(onDay).reduce((a,x)=>a+x.amount,0)+s.meals.filter(x=>onDay(x)&&x.food.id==='wasser'&&x.food.unit==='ml'&&x.food.k===0).reduce((a,x)=>a+x.amount,0);
  }
  function coachReply(s,text,now=new Date()){
    const q=text.toLocaleLowerCase('de-DE'),date=new Date(now);if(q.includes('vorgestern'))date.setDate(date.getDate()-2);else if(q.includes('gestern'))date.setDate(date.getDate()-1);
    const meals=s.meals.filter(x=>dayKey(new Date(x.date))===dayKey(date)),n=totals(meals),t=targets(s,date);
    if(/wasser|getrunken/.test(q))return `Für diesen Tag sind ${Math.round(waterTotal(s,date))} ml Wasser erfasst. Wasser aus Tagebuch und Wasserbuttons zählt zusammen. Dieselbe Portion bitte nur einmal erfassen.`;
    if(/berechn|bedarf|grundumsatz/.test(q)){const p=plan(s.profile,currentWeight(s,now));return p?`Geschätzter Ruhebedarf: ${Math.round(p.resting)} kcal. Mit Alltagsbewegung: etwa ${Math.round(p.maintenance)} kcal. Dein Ziel: ${p.kcal} kcal und ${p.protein} g Eiweiß. Grundlage: Mifflin–St Jeor. Aktivität ist bereits enthalten; Schritte und Training werden nicht doppelt als Essensbudget addiert.`:'Für eine Bedarfsschätzung unter Mein Plan Größe, Gewicht und Formel-Auswahl ergänzen und automatische Richtwerte einschalten. Für unter 18-Jährige und bei Untergewicht berechnen wir kein Ziel.';}
    if(/woche|durchschnitt/.test(q)){let count=0,sum=0;for(let i=0;i<7;i++){const d=new Date(now);d.setDate(d.getDate()-i);const entries=s.meals.filter(x=>dayKey(new Date(x.date))===dayKey(d));if(entries.length){count++;sum+=totals(entries).k;}}return count?`An ${count} der letzten 7 Tage ist Essen erfasst: durchschnittlich ${Math.round(sum/count)} kcal pro erfasstem Tag. Auch diese Tage können unvollständig sein; daraus lässt sich kein tatsächliches Kaloriendefizit ableiten.`:'Für die letzten sieben Tage fehlen noch Essenseinträge.';}
    if(/training|aktiv|sport|schritte/.test(q)){const minutes=s.workouts.filter(x=>dayKey(new Date(x.date))===dayKey(date)).reduce((a,x)=>a+x.minutes,0);return `${Math.round(minutes)} Trainingsminuten für diesen Tag erfasst. Deine Schritte stehen unter Bewegung. Die gewählte Alltagsaktivität ist bereits im Bedarf enthalten.`;}
    if(!meals.length)return 'Für diesen Tag ist noch keine Mahlzeit erfasst. Fehlende Einträge bedeuten nicht, dass du nichts gegessen hast. Trage etwas ein, dann berechne ich deine Bilanz.';
    if(/eiweiß|protein|muskel/.test(q))return `${Math.round(n.p)} g Eiweiß erfasst.${t.protein?` Richtwert: ${t.protein} g; rechnerisch noch ${Math.max(0,Math.round(t.protein-n.p))} g offen.`:' Es ist noch kein Eiweißrichtwert eingestellt.'} Eine Eiweißquelle wie Linsen, Tofu oder Quark kann eine Mahlzeit ergänzen. Hunger und Sättigung bleiben wichtig.`;
    if(/kalori|bilanz|gegessen|übrig|heute|gestern/.test(q))return `${Math.round(n.k)} kcal und ${Math.round(n.p)} g Eiweiß erfasst.${t.kcal?` Richtwert: ${t.kcal} kcal. ${n.k<=t.kcal?`Rechnerisch noch ${Math.round(t.kcal-n.k)} kcal offen.`:`${Math.round(n.k-t.kcal)} kcal darüber. Ein einzelner Tag ist kein Grund, Mahlzeiten auszulassen.`}`:''} Die Bilanz enthält nur deine Einträge; Portions- und Produktangaben beeinflussen die Genauigkeit.`;
    return 'Ich kann Kalorien, Eiweiß, Wasser, Trainingsminuten und den Wochendurchschnitt auswerten. Frage zum Beispiel: „Wie ist meine Bilanz heute?“. Ich arbeite lokal mit festen Auswertungen, ohne verbundenes KI-Modell. Mahlzeiten über Eintragen erfassen und bestätigen.';
  }
  function answerQuestion(s,text,now=new Date()) {const next=queueQuestion(s,text,now),entry=next.chat.at(-1);entry.status='local';entry.answer=coachReply(s,text,now);validate(next);return next;}
  const api={uid,dayKey,number,escape,foodValid,mealValid,nutrients,totals,initial,migrate,completeSetup,validate,parse,product,finite,dateValid,queueQuestion,plan,currentWeight,targets,waterTotal,coachReply,answerQuestion,dayScore};
  if(typeof module!=='undefined')module.exports=api;
  root.HFitCore=api;
})(typeof globalThis!=='undefined'?globalThis:this);
