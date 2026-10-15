const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
fs.mkdirSync(path.join(root,'artifacts'),{recursive:true});
const suites=['client-storage','resource-loading','layout-acceptance','art-v3-layout','client-acceptance'];
if(process.argv.includes('--full')) suites.push('title-acceptance','viewport-acceptance',
  'loading-acceptance','battle-health-acceptance','dialogue-acceptance','live2d-acceptance',
  'static-portraits-acceptance','improvements-acceptance','art-v3-acceptance');
const from=process.argv.indexOf('--from');
const start=from<0?0:suites.indexOf(process.argv[from+1]);
if(start<0){console.error('Unknown suite passed to --from');process.exit(2);}
for(const suite of suites.slice(start)){
  console.log('\nRunning '+suite);
  const result=spawnSync(process.execPath,[path.join('tests',suite+'.cjs')],{cwd:root,stdio:'inherit',env:process.env});
  if(result.error)throw result.error;
  if(result.status!==0)process.exit(result.status||1);
}
