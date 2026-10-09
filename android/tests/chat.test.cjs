const test=require('node:test'),assert=require('node:assert/strict'),C=require('../assets/core.js');
test('Questions are queued locally with no fabricated assistant response',()=>{
 const original=C.initial(),date=new Date('2026-10-05T12:00:00Z');original.chatDraft='Entwurf';
 const next=C.queueQuestion(original,'  Was kann ich morgen essen?  ',date);
 assert.equal(original.chat.length,0);assert.equal(next.chat.length,1);assert.equal(next.chat[0].role,'user');assert.equal(next.chat[0].status,'queued');assert.equal(next.chat[0].text,'Was kann ich morgen essen?');assert.equal(next.chat[0].date,date.toISOString());assert.equal(next.chatDraft,'');
});
test('Reject empty and overlong questions and bounded history',()=>{
 const s=C.initial();for(const value of ['','  ','a'.repeat(2001)])assert.throws(()=>C.queueQuestion(s,value));
 s.chat=Array.from({length:200},(_,i)=>({id:String(i),role:'user',status:'queued',text:'Frage',date:new Date().toISOString()}));assert.throws(()=>C.queueQuestion(s,'Noch eine Frage'));
});
test('Old backups migrate; chat history and drafts survive roundtrip',()=>{
 const old=C.initial();delete old.chat;delete old.chatDraft;old.water.push({id:'w',date:new Date().toISOString(),amount:250});
 const migrated=C.migrate(old);assert.equal(C.validate(migrated),true);assert.deepEqual(migrated.chat,[]);assert.equal(migrated.water[0].amount,250);
 const next=C.queueQuestion(migrated,'Eine Frage');next.chatDraft='Nächster Entwurf';const restored=C.migrate(JSON.parse(JSON.stringify(next)));assert.equal(C.validate(restored),true);assert.equal(restored.chat[0].text,'Eine Frage');assert.equal(restored.chatDraft,'Nächster Entwurf');
});
test('Imports reject forged replies, invalid dates, duplicates and oversized drafts',()=>{
 for(const patch of [{role:'assistant'},{status:'sent'},{text:''},{date:'invalid'}]){const s=C.queueQuestion(C.initial(),'Frage');Object.assign(s.chat[0],patch);assert.throws(()=>C.validate(s));}
 const s=C.queueQuestion(C.initial(),'Frage');s.chat.push(s.chat[0]);assert.throws(()=>C.validate(s));s.chat.pop();s.chatDraft='a'.repeat(2001);assert.throws(()=>C.validate(s));
});
