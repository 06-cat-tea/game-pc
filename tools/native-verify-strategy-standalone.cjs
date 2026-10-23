// Recheck the existing isolated checkout against current sources, retaining only its import cache.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),source=path.join(root,'godot'),reportPath=path.join(root,'artifacts/godot/standalone-build.json');
const previous=JSON.parse(fs.readFileSync(reportPath,'utf8')),isolated=path.resolve(previous.project),allowed=path.join(root,'artifacts/godot/isolated-checks');
assert(isolated.startsWith(allowed+path.sep));
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>{const p=path.join(dir,entry.name);return entry.isDirectory()?(['.godot','addons','build'].includes(entry.name)?[]:files(p)):[p];}).filter(p=>path.basename(p)!=='override.cfg');}
let synchronized=0;for(const f of files(source)){const target=path.join(isolated,path.relative(source,f));if(!fs.existsSync(target)||!fs.readFileSync(f).equals(fs.readFileSync(target))){fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(f,target);synchronized++;}}
const engine=path.join(root,'artifacts/godot/engine/godot.exe'),env={...process.env,APPDATA:path.join(root,'artifacts/godot/test-profile'),GODOT_PATH:engine};
const log=[];function run(binary,args){const r=cp.spawnSync(binary,args,{cwd:isolated,windowsHide:true,encoding:'utf8',env});const output=(r.stdout||'')+(r.stderr||'');log.push(output);fs.writeFileSync(path.join(root,'artifacts/godot/strategy-standalone.log'),log.join('\n'));if(r.error||r.status!==0||/SCRIPT ERROR:|^ERROR:/m.test(output))throw Error('Standalone check failed: '+output.slice(-3000));return output;}
run(engine,['--headless','--editor','--import','--recovery-mode','--path',isolated]);
env.ASHEN_REPORT=path.join(root,'artifacts/godot/standalone-acceptance.json');
const tested=run(engine,['--headless','--path',isolated,'--script','res://tests/test_suite.gd']);console.log(tested.split('\n').find(line=>line.includes('NATIVE ACCEPTANCE:')));
run(path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe'),['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(isolated,'build.ps1'),'-Action','export']);
const binary=path.join(isolated,'build/windows/灰烬边境.exe'),smoke=path.join(isolated,'standalone-runtime.json');
run(binary,['--headless','--','--view=battle','--smoke='+smoke]);
const details=JSON.parse(fs.readFileSync(smoke,'utf8'));assert(details.passed&&!details.editor_binary&&!details.dev_plugin_included);
fs.writeFileSync(reportPath,JSON.stringify({passed:true,project:isolated,binary,details,synchronized_files:synchronized,source_checked:'Current native project files synchronized byte-for-byte, excluding build/cache/development addons.'},null,2));console.log('Current isolated project rechecked and exported; synchronized '+synchronized+' files.');
