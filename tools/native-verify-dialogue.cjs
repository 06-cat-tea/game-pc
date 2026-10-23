const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/godot');
const source=path.resolve(process.argv[2]||path.join(out,'windows'));
const binary=path.join(source,'灰烬边境.exe'),report=path.join(out,'native-release-dialogue.json');
const profile=path.join(out,'test-profile');fs.mkdirSync(profile,{recursive:true});
// Export templates ignore the editor-only --script flag. Run the exported PCK
// in the matching editor runtime while keeping the test driver outside the pack.
const engine=process.env.GODOT_PATH||path.join(out,'engine/godot.exe');
const run=spawnSync(engine,['--main-pack',path.join(source,'灰烬边境.pck'),'--resolution','1280x720','--script',path.join(root,'godot/tests/check_dialogue_input.gd')],{cwd:source,encoding:'utf8',windowsHide:true,timeout:45000,env:{...process.env,APPDATA:profile,ASHEN_DEV_BRIDGE:'',ASHEN_DIALOGUE_REPORT:report,ASHEN_DIALOGUE_TEST_SOURCE:path.join(root,'godot/tests/dialogue_input_acceptance.gd')}});
const log=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(out,'native-release-dialogue.log'),log);
if(run.error||run.status!==0||/SCRIPT ERROR:|^ERROR:/m.test(log)||!fs.existsSync(report))throw Error('Release dialogue input regression failed: '+log.slice(-7000));
const result=JSON.parse(fs.readFileSync(report,'utf8'));if(!result.passed)throw Error(JSON.stringify(result));
result.binary=binary;result.checkedWith='Matching Godot editor runtime loading the exported PCK; external input driver excluded from delivery.';result.pckSha256=crypto.createHash('sha256').update(fs.readFileSync(path.join(source,'灰烬边境.pck'))).digest('hex');
fs.writeFileSync(report,JSON.stringify(result,null,2));console.log(JSON.stringify(result));
