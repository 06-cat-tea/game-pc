const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),directory=path.join(root,'artifacts/godot');fs.mkdirSync(directory,{recursive:true});
const args=process.argv.slice(2),sizeArg=args.find(value=>value.startsWith('--sizes='));
const reportArg=args.find(value=>value.startsWith('--report='));
const reportName=reportArg?reportArg.slice(9):sizeArg?'visual-layout-acceptance.json':'visual-acceptance.json';
if(!/^[\w-]+\.json$/.test(reportName))throw Error('Invalid visual report name');
const sizes=sizeArg?sizeArg.slice(8).split(',').map(value=>value.split('x').map(Number)):[[1920,1080],[1280,720]];
if(sizes.some(pair=>pair.length!==2||pair.some(value=>!Number.isInteger(value)||value<320||value>8192)))throw Error('Invalid capture sizes');
const requested=args.filter(value=>!value.startsWith('--sizes=')&&!value.startsWith('--report='));
const views=requested.length?requested:['title','new','town','room','terminal','character','party','skills','inventory','craft','journal','map','dialogue','topic','building','shop','actions','encounters','event','wheel','training','settings','saves','battle','battle-six','route-wall','route-drain','route-trial','map-room','map-route'];
const results=[];
for(const [width,height] of sizes) for(const view of views){
 const output=path.join(directory,`${view}-${width}x${height}.png`),log=path.join(directory,`${view}-${width}x${height}.log`);
 const r=spawnSync(process.execPath,[path.join(root,'tools/godot.cjs'),'run','--resolution','960x540','--script','res://tests/capture_view.gd','--','--view='+view,'--capture='+output,`--capture-size=${width}x${height}`],{cwd:root,encoding:'utf8',windowsHide:true,timeout:45000});
 fs.writeFileSync(log,(r.stdout||'')+(r.stderr||''));
 const errors=/SCRIPT ERROR:|^ERROR:/m.test((r.stdout||'')+(r.stderr||''));
 const layout=fs.existsSync(output+'.json')?JSON.parse(fs.readFileSync(output+'.json','utf8')):null;
 const png=fs.existsSync(output)?fs.readFileSync(output):null;
 const dimensionsPassed=png?.length>10000&&png.readUInt32BE(16)===width&&png.readUInt32BE(20)===height;
 const passed=r.status===0&&!errors&&dimensionsPassed&&layout?.passed===true;
 results.push({view,width,height,passed,output});console.log(`${passed?'PASS':'FAIL'} ${view} ${width}x${height}`);
 if(!passed){console.error(fs.readFileSync(log,'utf8').slice(-9000));process.exitCode=1;}
}
fs.writeFileSync(path.join(directory,reportName),JSON.stringify({passed:results.every(r=>r.passed),results},null,2));
