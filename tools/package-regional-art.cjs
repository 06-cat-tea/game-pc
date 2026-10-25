// Reproducible prompts and mechanical atlas extraction for the approved four-biome redesign.
const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),source=path.join(root,'art-source/regional-redraw/v1'),out=path.join(root,'godot/assets/regional-redraw');
const reference='art-source/regional-redraw/v1/approved-reference.png';
const common='Production-ready painted isometric fantasy RPG sprites matching the attached approved four-region concept. Match Morningstar Town craftsmanship: warm cream limestone, detailed weathered oak framing, individually painted blue slate or terracotta roof tiles, restrained greenery and fine material detail. Orthographic isometric 30 degree elevated view, front and right wall visible, identical camera and scale, neutral soft daylight from upper left. ONE SQUARE high-resolution transparent atlas in a strict 2 by 2 equal grid. Four entirely separate complete isolated objects, one centered in each cell, 14 percent empty transparent margin around every object and wide empty gutters. Keep every roof, blade, tree branch and base inside its own cell. Genuine alpha-zero background. No captions, letters, HUD, watermark, ground tile, floating island, perspective horizon, cast shadow, bloom or aura. Shadows and night lighting will be provided by the engine. No pre-lit bright windows. Do not include any neighboring buildings or large scenery behind a sprite. ';
const sheets=[
 ['wood-buildings',['forest-hut','moss-shrine','moon-well','windmill-farm'],[
  'A cozy single woodland cottage with blue slate roof, cream stone base, oak timber framing, modest cream awning, herb planters, stacked logs and a clearly visible wooden entrance. No surrounding forest.',
  'An ancient mossy stone shrine ruin, two broken tall arches around a small open court, carved lintel, subtle ivy and a clear walk-through front entrance. Compact recognizable silhouette, not an intact house.',
  'A small circular limestone moon well with still pale blue water, low carved rim, two slender partial pillars, tiny trailing flowers. No tree, no huge arched building, no glow.',
  'A handsome working windmill with a slender cream stone tower, terracotta cap and FOUR intact wooden sails, compact attached timber millhouse, sacks and a low step at its visible entry. Wheat fields will be separate game objects.'
 ]],
 ['pass-buildings',['waystation','grayforge','caravan-yard','ridge-barracks'],[
  'An ochre canyon caravan waystation, two-storey cream stone and oak, muted terracotta roof, shaded timber veranda, unlettered hanging sign and modest supply baskets, visible ground door.',
  'A functional grey stone forge workshop, blue slate gable roof, substantial brick chimney, open dark forge arch, anvils and tool rack sheltered under an attached lean-to. Furnace unlit in this daylight asset.',
  'A low practical mine caravan depot, heavy oak shed and small cream stone office, weathered terracotta roof, open loading bay, bundled supplies and spare wagon wheels, unique silhouette distinct from barracks.',
  'A compact ridge guard barracks with crenellated pale stone watch corner and low blue slate roof, disciplined timber gate, muted blue pennant without letters, a clear arched front door. Not a giant castle.'
 ]],
 ['fen-buildings',['sunken-temple','royal-crypt','moon-shrine','cloud-observatory'],[
  'A partly ruined wetland temple, pale weathered limestone gothic arches, one intact entry portico, broken roof, moss and subtle violet flowers. Front stone steps clearly visible. No water plane around it.',
  'An ancient royal crypt entrance, low solemn carved limestone mausoleum with squat dark blue roof, worn statues integrated at the sides, moss and a clearly visible recessed double door. No cemetery background.',
  'A small circular purification altar with a shallow blue water basin, four slender weathered columns, pale limestone dais and restrained carved star emblem. No magical light or aura.',
  'An elegant compact observatory, cream stone cylindrical tower with a modest brass-and-blue domed telescope roof, wraparound stone stair and visible ground door, weathered by wetland climate. It rests on the ground; no floating platform or island.'
 ]],
 ['coast-buildings',['lighthouse','fisher-hut','wreck-shrine','tide-harbor'],[
  'A graceful pale limestone cylindrical coastal lighthouse with brass glass lantern room, dark blue small cap, one low terracotta-roof attached keeper room and visible entrance. Entire lighthouse must be intact, no cliff pedestal.',
  'A weathered oak-and-cream-stone fisher cottage with blue slate roof, small cream awning, hanging ropes, modest fish baskets and visible doorway. No surrounding pier.',
  'A small maritime memorial shrine assembled from old ship ribs and carved pale stone, a short mast with a weathered blue pennant and a low offering basin. Grounded compact silhouette, no full ship.',
  'One modest standalone harbor administration office, two-storey cream limestone and oak with a blue slate roof, arched doorway and a small blue pennant. This is ONLY the office within a much larger multi-building harbor district. Do not attach warehouses, docks or other buildings to this office.'
 ]],
 ['harbor-facilities',['harbor-warehouse','harbor-fishmarket','harbor-boathouse','harbor-crane'],[
  'One substantial independent harbor warehouse, elongated weathered oak and cream limestone structure, low blue slate gable roof, large cargo doors and an upper loading hatch. Modest sacks and crates beside its own doors. No other buildings, water or docks.',
  'One independent open-sided covered fish auction market hall, low cream canvas and blue slate roof on oak posts, stone base, a few fish baskets and sorting tables under the canopy. No other buildings or pavement extending beyond its footprint.',
  'One independent coastal shipwright workshop and covered boathouse, weathered oak framing, terracotta roof, large open arch with an unfinished small boat hull inside, tools and spare timber. No dock or surrounding water.',
  'One tall functional medieval timber harbor loading crane with a wooden turning jib, rope pulley and a suspended small cargo net. Stable heavy oak base, entire crane complete and self-contained. No dock or boat beneath it.'
 ]],
 ['landmarks',['deep-mine','ember-fortress','violet-rift','fishing-boat'],[
  'A believable ochre canyon mine portal embedded in a self-contained irregular rock outcrop, heavy oak supports, dark tunnel opening, a short narrow-gauge rail stub and one ore basket. No large ground rectangle.',
  'A compact ruined ochre-limestone frontier fortress with broken crenellated towers, a visible stone gate and partial ruined walls, muted blue pennants, ivy sparingly. No lava, demons, fire or floating island.',
  'A wetland amethyst dungeon entrance: low weathered limestone arch built around a rocky fissure with a few violet crystals at the sides, dark accessible doorway, moss and subtle pale reeds. No glow or giant crystal explosion.',
  'One modest complete medieval fishing sailboat with oak hull, furled cream sail, coiled ropes and a small blue pennant. Isometric same camera, empty transparent background, no water, no dock, no shadow. Waterline near lower hull, no detached pieces.'
 ]],
 ['wood-props',['wood-oak','wood-birch','wood-garden','wheat-patch'],[
  'One full mature lush green oak tree with detailed branching canopy, visible trunk and roots, natural asymmetric silhouette.',
  'One full slender silver-barked birch tree with delicate green canopy and visible trunk, distinct from the oak.',
  'One low woodland garden corner: short weathered oak fence, ferns, white and pink wildflowers and a few small cream rocks. Low and compact, no tall tree.',
  'One dense small patch of ripe golden wheat with a few bent stalks and a little exposed earth at the roots. Irregular natural edges, no fence and no square platform.'
 ]],
 ['pass-props',['canyon-cliff','ore-supplies','forge-bench','mine-cart'],[
  'One irregular layered ochre sandstone cliff outcrop, angular but naturally weathered, a few cracks and sparse hardy grass, no rectangular terrain tile.',
  'One compact functional mining supply group: two ore crates, one barrel, sacks and a coil of rope, grounded single cluster.',
  'One sheltered blacksmith workbench with a small anvil, tongs, hammer, wood supports and a few tools; open structure, no roofed house.',
  'One small iron ore cart filled with dull grey ore on a SHORT intact pair of rails and sleepers. Compact standalone prop, no huge track or landscape.'
 ]],
 ['fen-props',['wetland-willow','wetland-reeds','ruin-wall','marsh-rock'],[
  'One complete graceful wetland willow tree with slender bent trunk and layered drooping blue-green foliage, visible roots, no water plane.',
  'One low natural wetland vegetation cluster: reeds, sedges, a few lily leaves and two small violet flowers. No water rectangle and no glow.',
  'One low broken cream limestone wall and partial column, moss and trailing ivy, small ruined masonry cluster, no complete shrine.',
  'One small cluster of weathered wetland limestone rocks with moss and tiny ferns, irregular low silhouette, no glow.'
 ]],
 ['coast-props',['fishing-rack','harbor-supplies','coastal-pine','coastal-rock'],[
  'One practical timber fishing rack with a loosely hung net, coiled rope and two woven baskets. Airy visible net mesh, entire rack intact.',
  'One compact harbor supply group: two worn oak barrels, a wooden fish crate, bundled rope, a small folded cream sailcloth. No lettering.',
  'One complete windswept coastal pine with bent trunk, dark sage green canopy and visible roots, elegant asymmetric silhouette.',
  'One irregular pale limestone sea rock outcrop with weathered cracks, sparse sea grass and two small white flowers, no water.'
 ]]
];
const specs=sheets.map(([id,names,objects])=>({id,names,transparent:true,prompt:common+objects.map((description,i)=>['TOP LEFT: ','TOP RIGHT: ','BOTTOM LEFT: ','BOTTOM RIGHT: '][i]+description).join(' ')}));
for(const [id,names,descriptions]of [
 ['ground',['wood-ground','pass-ground','fen-ground','coast-ground'],['muted natural woodland meadow grass with small clover and fine fallen leaves','warm ochre fine canyon soil with sparse gravel and subtle weathered rock grit','cool blue-green damp marsh turf, moss and fine dark peat, no standing water','pale sandy coastal earth with sparse sage grass and small limestone chips']],
 ['paths',['wood-road','pass-road','fen-road','coast-road'],['warm compacted earth woodland footpath, tiny gravel and faint leaf fragments, no grass border','ochre-grey compacted rocky canyon gravel path, natural varied pebbles, no railway','weathered irregular pale grey limestone paving with faint cool moss in seams, subtle broken edges within the material','warm pale limestone coastal cobblestone paving, gently worn and salt-weathered, fine sandy seams']]
])specs.push({id,names,transparent:false,prompt:'Game ground MATERIAL atlas, ONE SQUARE high resolution canvas precisely divided into 2x2 equal flush square swatches with NO gutter, border or labels. Each is an independently seamless repeatable top-down flat orthographic texture, even soft neutral daylight, no cast shadows, no perspective, no gradients, no objects or large plants. Match the fine painterly detailed materials of the attached approved fantasy game concept. Restrained varied natural color, not oversharpened. '+descriptions.map((d,i)=>['TOP LEFT: ','TOP RIGHT: ','BOTTOM LEFT: ','BOTTOM RIGHT: '][i]+d).join('. ')});

async function packageSheet(spec){
 const file=path.join(source,spec.id+'.png'),meta=await sharp(file).metadata();
 const cw=Math.floor(meta.width/2),ch=Math.floor(meta.height/2);
 let silhouettes=[];
 if(spec.transparent){
  const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const visited=new Uint32Array(info.width*info.height);let label=0;const components=[];
  for(let p=0;p<visited.length;p++){
   if(visited[p]||data[p*4+3]<100)continue;
   const queue=[p];visited[p]=++label;let x0=info.width,y0=info.height,x1=0,y1=0;
   for(let j=0;j<queue.length;j++){const q=queue[j],x=q%info.width,y=Math.floor(q/info.width);x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);for(const n of [x>0?q-1:-1,x<info.width-1?q+1:-1,y>0?q-info.width:-1,y<info.height-1?q+info.width:-1])if(n>=0&&!visited[n]&&data[n*4+3]>=100){visited[n]=label;queue.push(n);}}
   if(queue.length>1000)components.push({label,area:queue.length,x0,y0,x1,y1});
  }
  const major=components.sort((a,b)=>b.area-a.area).slice(0,4).sort((a,b)=>(a.y0+a.y1)-(b.y0+b.y1));
  if(major.length!==4)throw Error('Expected four isolated silhouettes: '+spec.id);
  silhouettes=[...major.slice(0,2).sort((a,b)=>a.x0-b.x0),...major.slice(2).sort((a,b)=>a.x0-b.x0)].map(c=>{
   const left=Math.max(0,c.x0-3),top=Math.max(0,c.y0-3),width=Math.min(info.width-left,c.x1-c.x0+7),height=Math.min(info.height-top,c.y1-c.y0+7),pixels=Buffer.alloc(width*height*4);
   for(let y=0;y<height;y++)for(let x=0;x<width;x++){const q=(top+y)*info.width+left+x;let belongs=visited[q]===c.label;if(!belongs&&data[q*4+3]>0&&data[q*4+3]<100)for(let dy=-2;dy<=2&&!belongs;dy++)for(let dx=-2;dx<=2;dx++){const n=q+dy*info.width+dx;if(n>=0&&n<visited.length&&visited[n]===c.label){belongs=true;break;}}if(belongs)data.copy(pixels,(y*width+x)*4,q*4,q*4+4);}
   return {pixels,width,height};
  });
 }
 for(let i=0;i<4;i++){
  const bounds={left:i%2*cw,top:Math.floor(i/2)*ch,width:cw,height:ch};
  let pipeline=sharp(file).extract(bounds);
  if(spec.transparent){
   const s=silhouettes[i];await sharp(s.pixels,{raw:{width:s.width,height:s.height,channels:4}}).extend({top:8,bottom:8,left:8,right:8,background:'#00000000'}).webp({lossless:true}).toFile(path.join(out,spec.names[i]+'.webp'));
  }else await pipeline.extract({left:4,top:4,width:cw-8,height:ch-8}).webp({quality:94}).toFile(path.join(out,spec.names[i]+'.webp'));
 }
 console.log('Packaged '+spec.id+': '+meta.width+'x'+meta.height);
}
async function main(){
 fs.mkdirSync(source,{recursive:true});fs.mkdirSync(out,{recursive:true});
 if(process.argv.includes('--prompts')){fs.writeFileSync(path.join(source,'prompts.json'),JSON.stringify({generator:'image_gen.imagegen',reference,specs},null,2)+'\n');return;}
 for(const spec of specs)await packageSheet(spec);
 if(fs.existsSync(path.join(source,'dock-material.png')))await sharp(path.join(source,'dock-material.png')).resize(1024,1024).webp({quality:94}).toFile(path.join(out,'dock-material.webp'));
 for(const name of fs.readdirSync(out).filter(n=>n.endsWith('.import'))){const file=path.join(out,name);fs.writeFileSync(file,fs.readFileSync(file,'utf8').replace('mipmaps/generate=false','mipmaps/generate=true'));}
 const zones=path.join(source,'emission-zones.json');
 if(fs.existsSync(zones)){const file=path.join(root,'godot/data/daylight.json'),settings=JSON.parse(fs.readFileSync(file));Object.assign(settings.emission_zones,JSON.parse(fs.readFileSync(zones)));fs.writeFileSync(file,JSON.stringify(settings,null,2)+'\n');}
 const mfile=path.join(root,'godot/data/resource-manifest.json'),manifest=JSON.parse(fs.readFileSync(mfile));
 for(const name of fs.readdirSync(out).filter(n=>n.endsWith('.webp')))manifest.files['assets/regional-redraw/'+name]=fs.statSync(path.join(out,name)).size;
 for(const id of ['wood','pass','fen','coast']){const relative='assets/refined-world/maps/'+id+'.png';manifest.files[relative]=fs.statSync(path.join(root,'godot',relative)).size;}
 fs.writeFileSync(mfile,JSON.stringify(manifest,null,2)+'\n');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
