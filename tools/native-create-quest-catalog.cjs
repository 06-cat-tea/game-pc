// Native catalog authoring: original narrative text stays in narrative.json.
const fs=require('node:fs');
const n=require('../godot/data/narrative.json'),c=require('../godot/data/content.json'),r=require('../godot/data/world-regions.json');
const world={revision:1,children:{},animals:[],resources:[],objects:[],entrances:[]};
for(const [id,name,x,y,line] of [['kid-luo','小洛',19.8,21.6,'团团最喜欢旅店的暖窗台。你愿意帮我找找它吗？'],['kid-aya','阿芽',39.4,25.8,'药草要认清叶子，照顾小动物也要慢慢来。'],['kid-ling','小铃',17.3,10.8,'礼拜堂每天都有新的信，也有等着吃饭的小伙伴。']])world.children[id]={name,type:'villager',place:'town',position:{x,y},line,role:'晨星镇的孩子',portrait:`res://assets/town-life/${id}/portrait.webp`,actor:`res://assets/town-life/${id}/actor.webp`};
for(const [id,name,species,x,y,width] of [['tuantuan','团团','橘猫',24.5,31,48],['amo','阿墨','黑白犬',39,9.8,62],['snowball','雪球','白兔',40,34,38],['diandian','点点','灰猫',33,26.4,45],['gugu','咕咕','母鸡',12.6,10.4,42],['doudou','豆豆','麻雀',29.5,16,28]])world.animals.push({id,name,species,scene:'town',point:[x,y],radius:.8,width,frames:[0,1,2].map(i=>`res://assets/town-life/${id}/${i}.webp`)});
for(const [id,x,y,material] of [['herb-1',12,12,'herb'],['herb-2',10.5,15,'herb'],['herb-3',14,15,'herb'],['ore-1',33,10.5,'ore'],['ore-2',33,7,'ore']])world.resources.push({id,scene:'town',point:[x,y],material,name:material==='herb'?'晨露药草':'浅层矿样'});
for(const [id,name,x,y,text] of [['pawprints','旅店窗下的爪印',23,30.5,'小小的梅花印一路通向暖窗台。'],['medicine-bag','点点身旁的小药包',33.5,27,'封口绳还在，药包没有被雨淋湿。'],['feeding-bowl','礼拜堂食盆位置',12.6,11.5,'这里背风，适合放一只稳稳的食盆。'],['chapel-mail','礼拜堂信箱',17.6,10,'将信笺放回归灯纹章的信箱。']])world.objects.push({id,name,scene:'town',point:[x,y],text});
for(const region of Object.keys(n.routes))for(let i=0;i<3;i++){
 const route=n.routes[region][i][0],building=Object.keys(n.entrances).find(b=>n.entrances[b]===route);
 let p;if(route==='town-drain')p=[22.5,14];else{const b=(region==='town'?c.buildings:r[region].buildings).find(b=>b.id===building); const a=c.art.buildings[b.id]||{};p=b.entry|| (a.entrySide==='x'?[b.x+b.w+1.5,b.y+b.d/2]:[b.x+b.w/2,b.y+b.d+1.5]);p=[p[0]+1,p[1]+.4];}
 world.entrances.push({id:'entrance-'+route,region,scene:route,building:route==='town-drain'?'':building,name:route==='town-drain'?'旧渠检修口':n.routes[region][i][1]+'入口',point:p,index:i,requires:i?n.routes[region][i-1][0]+':survey':''});
}
const quests={revision:1,tasks:{}};const add=(id,d)=>quests.tasks[id]={id,...d};
add('first',{ref:'quests:first',category:'探索',giver:'guild-clerk',turnin:'board',board:true});
for(const id of Object.keys(n.quests).filter(id=>!['first','stars'].includes(id))){const giver=Object.keys(n.oldQuest).find(k=>n.oldQuest[k]===id)||({pages:'sylvi',caravan:'toren',candle:'eira',moon:'eira',wreck:'lian',pact:'eira'}[id]);add('quest:'+id,{ref:'quests:'+id,category:'居民',giver,turnin:giver,board:false,...(id==='herbs'?{materials:{herb:3}}:{})});}
for(const region of Object.keys(n.routes))for(const kind of ['regional','expeditions'])add(kind+':'+region,{ref:kind+':'+region,category:'探索',giver:n[kind][region].npc,turnin:n[kind][region].npc,region,board:kind==='expeditions',discover:kind==='expeditions'?'entrance-'+n.routes[region][0][0]:''});
for(const id of Object.keys(c.personal))add('personal:'+id,{ref:'personal:'+id,category:'个人',giver:id,turnin:id,materials:id==='eira'?{herb:1}:id==='alchemist'?{herb:3}:{},board:false});
const prog=require('../godot/data/progression.json');for(const [id,d] of Object.entries(prog.buildings))if(['commission','research','order'].includes(d.type))add('service:'+id,{ref:'service:'+id,category:d.type==='commission'?'采集':'研究',giver:id,turnin:id==='guildhall'?'board':'service:'+id,board:id==='guildhall',materials:d.material?{[d.material]:d.amount}:{}});
add('guild-ore',{name:'公会矿样征集',desc:'为公会带回两份矿石样本，已有库存也可以使用。',category:'采集',giver:'guild-clerk',turnin:'board',board:true,materials:{ore:2},reward:{xp:20,gold:14}});
for(const [id,route,name,xp,gold] of [['patrol','town-wall','巡径清剿',25,15],['drain','town-drain','旧渠清理',35,20]])add('battle:'+id,{name,desc:'接取后在'+n.scenes[route].title+'取得一次普通战斗胜利。',category:'战斗',giver:'guild-clerk',turnin:'board',board:true,discover:'entrance-'+route,unlocked:route,steps:[{event:'battle',scene:route}],reward:{xp,gold}});
for(const [id,name,giver,requires,steps,xp,gold,grants] of [
 ['cat','团团躲哪了','kid-luo','',[['inspect','pawprints'],['animal','tuantuan']],20,10,{}],
 ['dog','安静的马厩','kid-luo','resident:cat',[['animal','amo']],20,12,{}],
 ['rabbit','雪球的午餐','kid-aya','',[['feed','snowball']],15,8,{leaf:1}],
 ['bag','丢失的小药包','kid-aya','resident:rabbit',[['inspect','medicine-bag']],25,12,{}],
 ['hen','咕咕的新食盆','kid-ling','',[['place','feeding-bowl'],['feed','gugu']],15,8,{bowl:1,feed:1}],
 ['letter','飞回来的信','kid-ling','resident:hen',[['animal','doudou'],['deliver','chapel-mail']],25,12,{}]
 ])add('resident:'+id,{name,desc:{cat:'调查旅店爪印，再找到橘猫团团。',dog:'去马厩附近安抚黑白犬阿墨。',rabbit:'用阿芽准备的嫩叶喂白兔雪球。',bag:'取回灰猫点点身边的小药包。',hen:'安置食盆，再喂母鸡咕咕。',letter:'从麻雀豆豆处取得信笺，放入礼拜堂信箱。'}[id]+'完成后返回委托人交付。',category:'居民',giver,turnin:giver,board:true,requires,steps:steps.map(([event,target])=>({event,target,scene:'town'})),reward:{xp,gold},grants});
for(const [file,data] of [['world-interactions',world],['quest-catalog',quests]])fs.writeFileSync(`godot/data/${file}.json`,JSON.stringify(data,null,2)+'\n');
