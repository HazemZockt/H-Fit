const {spawnSync}=require('node:child_process');
const path=require('node:path');
for(const suite of ['ui','onboarding-ui','chat-ui','planning-ui']){
 const result=spawnSync(process.execPath,[path.join(__dirname,suite+'.test.cjs')],{stdio:'inherit'});
 if(result.error)throw result.error;
 if(result.status!==0)process.exit(result.status??1);
}
