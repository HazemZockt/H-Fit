const test=require('node:test');
const assert=require('node:assert/strict');
const C=require('../assets/core.js');
const now=new Date('2026-10-05T12:00:00Z');
const draft={name:'  Alex  ',age:'25',height:'175',weight:'75,5',goal:'build',activity:'moderate'};
test('Setup stores profile and starting weight exactly once',()=>{
 const original=C.initial(),s=C.completeSetup(original,draft,now);
 assert.equal(original.setupComplete,false);assert.equal(s.setupComplete,true);
 assert.equal(s.profile.name,'Alex');assert.equal(s.profile.age,25);assert.equal(s.profile.height,175);assert.equal(s.profile.weight,75.5);
 assert.equal(s.weights.length,1);assert.equal(s.weights[0].value,75.5);assert.equal(s.weights[0].date,now.toISOString());
 assert.equal(C.completeSetup(s,draft,now).weights.length,1);
 assert.equal(C.completeSetup(s,{...draft,weight:'76'},now).weights.length,2);
});
test('Body measurements are optional and empty is not zero',()=>{
 const s=C.completeSetup(C.initial(),{...draft,height:'',weight:''},now);
 assert.equal(s.profile.height,null);assert.equal(s.profile.weight,null);assert.equal(s.weights.length,0);
});
test('Reject incomplete, nonfinite and out-of-range setup fields',()=>{
 for(const patch of [{name:' '},{age:''},{age:'17.5'},{age:'121'},{age:'Infinity'},{height:'10'},{weight:'0'},{weight:'NaN'},{activity:''},{goal:'unknown'}])assert.throws(()=>C.completeSetup(C.initial(),{...draft,...patch},now));
});
test('Age determines adult status and clears adult-only settings for minors',()=>{
 const previous=C.initial();previous.profile.adult=true;previous.profile.kcal=2000;previous.profile.protein=150;previous.fastStart=now.toISOString();
 const s=C.completeSetup(previous,{...draft,age:'16',goal:'lose'},now);
 assert.equal(s.profile.adult,false);assert.equal(s.profile.goal,'balance');assert.equal(s.profile.kcal,0);assert.equal(s.profile.protein,0);assert.equal(s.fastStart,null);
 s.profile.adult=true;assert.throws(()=>C.validate(s));
});
test('Legacy backups migrate without discarding diary or goals',()=>{
 const old=C.initial();delete old.setupComplete;for(const k of ['age','height','weight','activity'])delete old.profile[k];
 old.profile.adult=true;old.profile.kcal=2200;old.water.push({id:'water',date:now.toISOString(),amount:250});old.weights.push({id:'weight',date:now.toISOString(),value:80});
 const s=C.migrate(JSON.parse(JSON.stringify(old)));assert.equal(C.validate(s),true);assert.equal(s.setupComplete,false);assert.equal(s.profile.age,null);
 const completed=C.completeSetup(s,draft,now);assert.equal(completed.water[0].amount,250);assert.equal(completed.weights[0].value,80);assert.equal(completed.weights.length,1);assert.equal(completed.profile.kcal,2200);
});
test('Import validates completed profiles rather than trusting the flag',()=>{
 const s=C.initial();s.setupComplete=true;assert.throws(()=>C.validate(s));
 const valid=C.completeSetup(C.initial(),draft,now);assert.equal(C.validate(JSON.parse(JSON.stringify(valid))),true);
});
