const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
function run(file,args){const r=spawnSync(process.execPath,[path.join(root,file),...args],{cwd:root,stdio:'inherit',windowsHide:true});if(r.status!==0)throw Error(file+' failed');}
run('tools/import-godot-regions.cjs',[]);
run('tools/godot.cjs',['import']);
// Terrain minification needs mipmaps for stable fine details at every display resolution.
for(const file of fs.readdirSync(path.join(root,'godot/assets/regions/terrain')))if(file.endsWith('.import')){
 const target=path.join(root,'godot/assets/regions/terrain',file);fs.writeFileSync(target,fs.readFileSync(target,'utf8').replace('mipmaps/generate=false','mipmaps/generate=true'));
}
run('tools/godot.cjs',['import']);
run('tools/godot.cjs',['run','--resolution','960x540','--script','res://tests/bake_world.gd','--','--regions-only']);
run('tools/godot.cjs',['import']);
const target=path.join(root,'godot/data/resource-manifest.json'),manifest=JSON.parse(fs.readFileSync(target));
for(const id of ['wood','pass','fen','coast','city']){const file='assets/refined-world/maps/'+id+'.png';manifest.files[file]=fs.statSync(path.join(root,'godot',file)).size;}
manifest.regions='data/world-regions.json';fs.writeFileSync(target,JSON.stringify(manifest,null,2));
console.log('Five independent native regions and their actual scene overviews are ready.');
