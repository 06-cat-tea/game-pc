const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),source=path.join(root,'art-source/item-icons/v1'),out=path.join(root,'godot/assets/ui/items');
const icons={potion:'health-normal',tonic:'round-bottom-flask',revive:'life-in-the-balance',herb:'three-leaves',ore:'ore',shard:'crystal-shine',gold:'two-coins',supply:'knapsack',physical:'broadsword',fire:'flame',astral:'star-swirl',holy:'holy-symbol',poison:'poison-bottle',shield:'shield',burn:'flame',bleed:'bleeding-wound',regen:'healing',vulnerable:'target-arrows',armorBreak:'cracked-shield',silence:'silenced',blind:'semi-closed-eye',guard:'shield-reflect',taunt:'screaming',broken:'cracked-shield',stun:'knockout',weaken:'despair',riposte:'shield-reflect',balanced:'balance',assault:'crossed-swords',watch:'shield'};
const colors={potion:'#b86560',tonic:'#788db7',revive:'#c5a65d',herb:'#739373',ore:'#8794a2',shard:'#a194c0',gold:'#ba9654',fire:'#c18155',astral:'#9c88bb',holy:'#c1aa68',poison:'#6e9e8b'};
icons.fire='fire';icons.burn='fire';icons.ore='stone-pile';icons.balanced='scales';icons.stun='stars-stack';
icons.potion='heart-bottle';icons.revive='magic-potion';
async function main(){
 fs.mkdirSync(source,{recursive:true});fs.mkdirSync(out,{recursive:true});const catalog={version:1,icons:{}};
 await Promise.all(Object.entries(icons).map(async ([id,slug])=>{
  let url,svg,author;
  for(const candidate of ['lorc','delapouite','sbed']){
   url='https://game-icons.net/icons/000000/transparent/1x1/'+candidate+'/'+slug+'.svg';
   const sourceFile=path.join(source,candidate+'-'+slug+'.svg');
   if(fs.existsSync(sourceFile)){svg=fs.readFileSync(sourceFile,'utf8');author=candidate;break;}
   if(fs.existsSync(path.join(source,'game-icons.svg.zip')))continue;
   const r=await fetch(url,{signal:AbortSignal.timeout(25000)});if(r.status===404)continue;if(!r.ok)throw Error(id+' '+r.status);
   svg=await r.text();if(!svg.includes('<svg'))throw Error('Invalid SVG '+id);fs.writeFileSync(sourceFile,svg);author=candidate;break;
  }
  if(!author)throw Error('No authored icon found: '+id+' / '+slug);
  // Remove the stock black background path, preserve the authored silhouette.
  const body=svg.replace(/<rect[^>]*\/>/g,'').replace(/<path[^>]*d="M0 0h512v512H0z"[^>]*\/>/g,'').replace(/#(?:000000|ffffff|000|fff)\b/g,colors[id]||'#947c50');
  fs.writeFileSync(path.join(out,id+'.svg'),body);
  catalog.icons[id]={path:'res://assets/ui/items/'+id+'.svg',author:{lorc:'Lorc',delapouite:'Delapouite',sbed:'sbed'}[author],license:'CC BY 3.0',source:url,page:'https://game-icons.net/1x1/'+author+'/'+slug+'.html',modifications:'Recolored for Ashen Frontier; transparent background.'};
 }));
 fs.writeFileSync(path.join(root,'godot/data/item-icons.json'),JSON.stringify(catalog,null,2)+'\n');
 const credit='Game-icons.net item and combat icons\n\nIcons by Lorc, Delapouite and sbed, available at https://game-icons.net\nLicense: Creative Commons Attribution 3.0 Unported\nhttps://creativecommons.org/licenses/by/3.0/\n\nChanges: recolored, transparent background. Original sources, per-icon links and attribution are recorded in data/item-icons.json; authoring originals are retained in art-source/item-icons/v1.\n\n'+Object.entries(catalog.icons).map(([id,v])=>id+' ('+v.author+'): '+v.page).join('\n')+'\n';
 fs.writeFileSync(path.join(root,'godot/LICENSE-Icons-CC-BY-3.0.txt'),credit);console.log('Packaged '+Object.keys(icons).length+' icons.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
