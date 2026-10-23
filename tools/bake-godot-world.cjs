// Authoring only: prepares CC0 assets and bakes the actual 2D scenes through Godot.
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process'),sharp=require('sharp');
const root=path.resolve(__dirname,'..');
function run(file,args){const r=spawnSync(process.execPath,[path.join(root,file),...args],{cwd:root,stdio:'inherit',windowsHide:true});if(r.status!==0)throw Error(file+' failed');}
async function main(){
 run('tools/prepare-godot-world.cjs',[]);
 run('tools/godot.cjs',['import']);
 run('tools/godot.cjs',['run','--resolution','960x540','--script','res://tests/bake_world.gd','--','--rocks-only']);
 for(let i=1;i<=5;i++){const f=path.join(root,`godot/assets/refined-world/rock-${i}.png`);fs.writeFileSync(f,await sharp(f).trim().modulate({saturation:.7,brightness:1.05}).png().toBuffer());}
 run('tools/godot.cjs',['import']);
 run('tools/godot.cjs',['run','--resolution','960x540','--script','res://tests/bake_world.gd']);
 run('tools/godot.cjs',['import']);
 const manifestFile=path.join(root,'godot/data/resource-manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile));
 for(const file of fs.readdirSync(path.join(root,'godot/assets/refined-world'),{recursive:true}))if(/\.(png|svg)$/.test(file)){const relative='assets/refined-world/'+file.replaceAll('\\','/');manifest.files[relative]=fs.statSync(path.join(root,'godot',relative)).size;}
 manifest.presentation='data/presentation.json';manifest.thirdParty='assets/refined-world/catalog.json';
 fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2));
 console.log('World resources and all 15 scene overviews are ready.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
