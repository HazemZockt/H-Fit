const test=require('node:test'),assert=require('node:assert/strict'),C=require('../assets/core.js');
const now=new Date('2026-10-05T12:00:00Z');
test('Day rings require complete adult data and penalize both calorie extremes',()=>{
 const s=C.initial();s.profile={...s.profile,adult:true,kcal:2000,protein:100};
 s.meals=[{id:'test',date:now.toISOString(),amount:1000,food:{id:'food',name:'Test',aliases:[],portion:100,unit:'g',k:200,p:10,c:20,f:5}}];
 assert.equal(C.dayScore(s,now),null);s.completedDays=[C.dayKey(now)];assert.equal(C.dayScore(s,now),1);
 s.meals[0].amount=2000;assert.equal(C.dayScore(s,now),.3);
 s.meals[0].amount=100;assert.ok(C.dayScore(s,now)<.1);
 s.profile.adult=false;assert.equal(C.dayScore(s,now),null);s.profile.adult=true;s.profile.protein=0;assert.equal(C.dayScore(s,now),null);
 s.completedDays=['2026-02-30'];assert.throws(()=>C.validate(s));
});
const profile={name:'Alex',adult:true,age:30,height:180,weight:80,sex:'male',automatic:true,activity:'moderate',goal:'balance',kcal:0,protein:0};
test('Reference energy and macro calculations with conservative goal adjustments',()=>{
 const p=C.plan(profile);assert.equal(p.resting,1780);assert.equal(p.maintenance,2670);assert.equal(p.kcal,2670);assert.equal(p.protein,96);
 assert.equal(C.plan({...profile,sex:'female'}).resting,1614);
 assert.equal(C.plan({...profile,goal:'lose'}).kcal,2400);
 const b=C.plan({...profile,goal:'build'});assert.equal(b.kcal,2800);assert.equal(b.protein,128);assert.ok(Math.abs(b.kcal-(b.protein*4+b.carbs*4+b.fat*9))<=5);
});
test('Missing measurements, opt out, minors and underweight get no invented target',()=>{
 for(const patch of [{height:null},{weight:null},{sex:'unspecified'},{age:17},{adult:false},{automatic:false},{weight:50},{weight:Infinity},{activity:null}])assert.equal(C.plan({...profile,...patch}),null);
});
test('Latest nonfuture weight recalculates target, and training is not double counted',()=>{
 const s=C.initial();s.profile={...profile};const original=C.targets(s,now).kcal;
 s.weights=[{date:now.toISOString(),value:85},{date:'2026-10-06T12:00:00Z',value:90}];assert.equal(C.currentWeight(s,now),85);assert.ok(C.targets(s,now).kcal>original);
 s.weights=[];s.workouts=[{date:now.toISOString(),minutes:100}];assert.equal(C.targets(s,now).kcal,original);
 s.profile.automatic=false;s.profile.kcal=2100;assert.equal(C.targets(s,now).kcal,2100);
});
test('Onboarding opt-in clears old manual targets and respects minor transition',()=>{
 const s=C.initial();s.profile.adult=true;s.profile.kcal=2200;
 const draft={...profile,age:'30',height:'180',weight:'80'};
 const next=C.completeSetup(s,draft,now);assert.equal(next.profile.kcal,0);assert.equal(C.targets(next,now).kcal,2670);
 const minor=C.completeSetup(next,{...draft,age:'16'},now);assert.equal(minor.profile.automatic,false);assert.equal(C.targets(minor,now).kcal,0);
});
test('Water totals include diary water, respect dates and respond to edits',()=>{
 const s=C.initial(),food={id:'wasser',unit:'ml',k:0};s.water=[{date:now.toISOString(),amount:250}];s.meals=[{date:now.toISOString(),food,amount:500},{date:'2026-10-04T12:00:00Z',food,amount:1000}];
 assert.equal(C.waterTotal(s,now),750);s.meals[0].amount=300;assert.equal(C.waterTotal(s,now),550);
});
test('Local assistant persists an actual computed answer without any network',()=>{
 const s=C.initial();s.profile={...profile};s.meals=[{id:'m',date:now.toISOString(),food:{id:'food',name:'Test',unit:'g',aliases:[],portion:100,k:200,p:10,c:20,f:5},amount:150}];
 const next=C.answerQuestion(s,'Wie ist meine Bilanz heute?',now);assert.equal(next.chat[0].status,'local');assert.match(next.chat[0].answer,/300 kcal/);assert.equal(s.chat.length,0);assert.equal(C.validate(JSON.parse(JSON.stringify(next))),true);
 assert.match(C.coachReply(s,'Meine Woche',now),/1 der letzten 7/);assert.match(C.coachReply(s,'Meine Woche',now),/300 kcal/);
 next.chat[0].answer='';assert.throws(()=>C.validate(next));
});
test('Absent meals are missing data, not a consumption claim',()=>{assert.match(C.coachReply(C.initial(),'Bilanz heute',now),/nicht, dass du nichts gegessen hast/);});
