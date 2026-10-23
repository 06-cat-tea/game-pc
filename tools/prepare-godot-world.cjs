// CC0 source processing; originals remain in desktop/art-source/godot-cc0.
const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),source=path.join(root,'art-source/godot-cc0'),out=path.join(root,'godot/assets/refined-world');
const content=JSON.parse(fs.readFileSync(path.join(root,'godot/data/content.json')));
async function main(){
 fs.mkdirSync(out,{recursive:true});
 for(const name of ['grass','dirt','sand','pavement'])await sharp(path.join(source,name+'.png')).modulate({saturation:name==='grass'?.42:.58,brightness:name==='grass'?.74:1.05}).png().toFile(path.join(out,name+'.png'));
 // Solid diamond is the shared tile geometry. Texture sampling uses world coordinates.
 // Overlapping rectangular tile coverage removes alpha cracks along isometric edges.
 // Each fragment still uses the same world UV, including the road transition masks.
 await sharp({create:{width:96,height:48,channels:4,background:'#ffffff'}}).png().toFile(path.join(out,'diamond.png'));
 // Road mask is oversampled and softened once, never rebuilt while moving.
 const mask=Buffer.alloc(64*48);
 for(let y=0;y<48;y++)for(let x=0;x<64;x++)mask[y*64+x]=content.terrain[y][x]==='road'?255:0;
 await sharp(mask,{raw:{width:64,height:48,channels:1}}).resize(1024,768,{kernel:'cubic'}).blur(3.2).png().toFile(path.join(out,'road-mask.png'));
 const available=fs.readdirSync(path.join(source,'plants/isometric tiles'));
 const chosen=available.filter(n=>/^(bush|grass|shrub|weed)/i.test(n)).slice(0,18);
 for(let i=0;i<chosen.length;i++)await sharp(path.join(source,'plants/isometric tiles',chosen[i])).trim().modulate({saturation:.6,brightness:1.65}).png().toFile(path.join(out,`plant-${i}.png`));
 const icons=fs.readdirSync(path.join(source,'cartography/PNG/Default')).filter(n=>/town|castle|tower|tree|cross|flag|mountain|house/i.test(n)).slice(0,10);
 for(let i=0;i<icons.length;i++)await sharp(path.join(source,'cartography/PNG/Default',icons[i])).trim().resize({width:64,height:64,fit:'inside'}).png().toFile(path.join(out,`landmark-${i}.png`));
 const shadow='<svg xmlns="http://www.w3.org/2000/svg" width="512" height="192"><defs><radialGradient id="s"><stop stop-color="#273b2c" stop-opacity=".32"/><stop offset="1" stop-color="#273b2c" stop-opacity="0"/></radialGradient></defs><ellipse cx="256" cy="96" rx="256" ry="96" fill="url(#s)"/></svg>';
 fs.writeFileSync(path.join(out,'contact-shadow.svg'),shadow);
 const decor=[];
 const entry=b=>content.art.buildings[b.id].entrySide==='x'?[b.x+b.w+1.5,b.y+b.d/2]:[b.x+b.w/2,b.y+b.d+1.5];
 const npcs=Object.values(content.npcs).filter(n=>n.position&&(!n.place||n.place==='town')).map(n=>[n.position.x,n.position.y]);
 const safe=(p,large)=>{
  if(p[0]<2||p[1]<2||p[0]>61||p[1]>45)return false;
  if(content.terrain[Math.floor(p[1])][Math.floor(p[0])]==='road')return false;
  if([...content.buildings.map(entry),...npcs,[30,27]].some(e=>Math.hypot(e[0]-p[0],e[1]-p[1])<(large?2.7:1.65)))return false;
  // Tall scenery belongs inside already blocked plots or at the outer green belt.
  if(large&&!content.buildings.some(b=>p[0]>b.x&&p[0]<b.x+b.w&&p[1]>b.y&&p[1]<b.y+b.d)&&p[0]>5&&p[0]<58&&p[1]>5&&p[1]<42)return false;
  return true;
 };
 const add=(p,asset,width,large=false,group='garden')=>{if(safe(p,large))decor.push({point:p,asset,width,large,group,anchor:[.5,.93]});};
 for(const b of content.buildings){
  const slots=[[b.x-.6,b.y-.5],[b.x+b.w+.6,b.y-.4],[b.x-.7,b.y+b.d*.6],[b.x+b.w*.3,b.y+b.d+.8]];
  slots.forEach((p,i)=>{add(p,['chapel','inn','alchemist-lab','star-academy'].includes(b.id)&&i%2===0?'res://assets/refined-world/flowers.svg':`res://assets/refined-world/plant-${(i+b.x)%Math.min(chosen.length,8)}.png`,48+i*7,false,b.id);});
  if(['market','inn','town-stables','guildhall'].includes(b.id))add([b.x-.6,b.y-.3],content.art.environment[b.id==='market'?'town-village-09-supplies':'town-forest-12-barrels'],64,false,b.id);
 }
 for(let i=0;i<44;i++){
  const p=i%2?[3+(i*13)%58,3+(i%3)*1.2]:[3+(i%3)*1.2,5+(i*7)%38];
  add(p,content.art.environment['town-forest-01-oak'],145+i%4*18,true,'green-belt');
  add([p[0]+1.6,p[1]+1],`res://assets/refined-world/plant-${i%chosen.length}.png`,52,false,'green-belt');
 }
 for(let i=0;i<10;i++)add([3+(i*17)%56,3+(i*11)%40],`res://assets/refined-world/rock-${i%5+1}.png`,57,false,'stone-garden');
 const ambience=Object.fromEntries(Object.keys(content.scenes).map(id=>[id,{overlay:'res://assets/refined-world/ambience.svg',tint:id==='town-drain'?'e6edf6':'fff0d6',opacity:id.startsWith('town-')?.10:.065,foreground:'retained painted frame',contactShadow:'res://assets/refined-world/contact-shadow.svg'}]));
 const presentation={version:1,coordinates:{town:{origin:[0,0],axisX:[48,24],axisY:[-48,24]},scene:{origin:[960,170],axisX:[82.8,41.4],axisY:[-82.8,41.4]}},mapBounds:{town:[-2352,-384,5472,3168],scene:[0,0,1920,1080]},decor,ambience,plants:chosen,landmarks:icons};
 fs.writeFileSync(path.join(root,'godot/data/presentation.json'),JSON.stringify(presentation,null,2));
 const packs=[['ground','Drummyfish','https://opengameart.org/content/4-hand-painted-ground-textures',['grass.png','dirt.png','sand.png','pavement.png']],['plants','Rubberduck / Yughues','https://opengameart.org/content/free-isometric-plants-pack',['plants.zip']],['rocks','Rubberduck','https://opengameart.org/content/handpainted-style-rocks',['rocks.zip']],['cartography','Kenney','https://kenney.nl/assets/cartography-pack',['cartography.zip']]].map(([id,author,url,files])=>({id,author,url,license:'CC0-1.0',files:files.map(file=>({file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(source,file))).digest('hex')}))}));
 fs.writeFileSync(path.join(source,'sources.json'),JSON.stringify({downloaded:'2026-10-16',packs,processing:'tools/prepare-godot-world.cjs; godot/tests/bake_world.gd; Godot 4.7.2 Compatibility renderer. Models converted to 2D PNG during authoring only.'},null,2));
 fs.writeFileSync(path.join(root,'godot/assets/refined-world/catalog.json'),JSON.stringify({packs,plants:chosen,landmarks:icons,decor:decor.length},null,2));
 fs.writeFileSync(path.join(root,'godot/LICENSE-ThirdParty-CC0.txt'),'CC0 1.0 Universal\nhttps://creativecommons.org/publicdomain/zero/1.0/\n\n'+packs.map(p=>p.id+' — '+p.author+'\n'+p.url).join('\n\n')+'\n\nOriginal archives, source pages and the full CC0 legal code: desktop/art-source/godot-cc0.\nProcessing and runtime use: docs/Godot-浅色界面与场景优化.md.\n');
 // OBJ is imported solely by the authoring bake, never exported into the game.
 const bake=path.join(root,'godot/authoring/rocks');fs.mkdirSync(bake,{recursive:true});fs.writeFileSync(path.join(root,'godot/authoring/.gdignore'),'');
 for(let i=1;i<=5;i++)for(const ext of ['obj','png'])fs.copyFileSync(path.join(source,`rocks/rock${i}/rock${i}.${ext}`),path.join(bake,`rock${i}.${ext}`));
 console.log(`Prepared ${chosen.length} plants, ${icons.length} legends, ${decor.length} curated placements.`);
}
main().catch(e=>{console.error(e);process.exitCode=1;});
