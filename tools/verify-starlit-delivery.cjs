// Smoke the exported Windows game with an isolated profile and no development dependencies.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),directory=path.join(root,'artifacts/godot/starlit-delivery'),binary=path.join(root,'artifacts/godot/windows/灰烬边境.exe');
fs.mkdirSync(directory,{recursive:true});
const profile=path.join(directory,'profile');fs.mkdirSync(profile,{recursive:true});
const env={...process.env,APPDATA:profile,GODOT_PATH:'',NODE_PATH:'',ASHEN_DEV_BRIDGE:'',PATH:path.join(process.env.SystemRoot,'System32')};
const results=[];
for(const view of ['world','character','inventory','journal','map','battle-six','region-city','region-city-night','town-life-night','wheel-selected']){
 const capture=path.join(directory,view+'.png'),smoke=path.join(directory,view+'.json');
 const r=spawnSync(binary,['--resolution','1280x720','--','--view='+view,'--capture='+capture,'--smoke='+smoke],{cwd:directory,env,encoding:'utf8',windowsHide:true,timeout:45000});
 const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,view+'.log'),log);
 assert.equal(r.status,0,view+': '+log);assert(!/SCRIPT ERROR:|^ERROR:/m.test(log),view+': '+log);
 const runtime=JSON.parse(fs.readFileSync(smoke)),layout=JSON.parse(fs.readFileSync(capture+'.json'));
 assert(runtime.passed&&!runtime.editor_binary&&!runtime.dev_plugin_included&&!runtime.test_sources_included&&!runtime.authoring_included,view+' isolated release');
 assert(layout.passed,view+' layout');if(view==='region-city-night'||view==='town-life-night')assert(runtime.daylight.phase===3&&runtime.daylight.active_lights<=8&&runtime.daylight.outdoor,view+' real night lighting');if(view.startsWith('region-city'))assert(runtime.daylight.city_buildings===52&&runtime.daylight.design_version===2,view+' rebuilt city');assert(fs.statSync(capture).size>50000,view+' rendered screenshot');results.push({view,passed:true,capture});console.log('PASS Windows release: '+view);
}
fs.writeFileSync(path.join(directory,'report.json'),JSON.stringify({passed:true,results,environment:'Isolated APPDATA; System32-only PATH; no Node or Godot editor dependency'},null,2));
