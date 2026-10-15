(() => {
  'use strict';
  const routes={
    town:[['town-wall','城墙巡径','黄昏的城墙步道，石垛、巡夜灯、箭架和远处蓝瓦王城',2],['town-drain','旧城地下渠','旧城下的拱形排水渠，铜闸、浅水、维护栈道和发光旧铭文',3],['town-trial','公会试炼场','宽敞的公会训练圆厅，木盾、旗帜、观众席和沙土地面',4]],
    wood:[['wood-trail','银叶深径','银叶森林深处的曲折石径，苔石、银色树叶、药草和小溪',3],['wood-roots','古根洞窟','巨树根系包围的地下洞窟，荧光蘑菇、树根桥和精灵石碑',5],['wood-well','月井下层','月井底部的精灵遗迹，月光泉水、断柱、银铃和浅水石台',6]],
    pass:[['pass-path','栈道岔路','峡谷悬崖的石木栈道岔路，矿车轨道、绳索与赤色山壁',4],['pass-mine','灰炉旧矿层','深山废矿，岩柱、木支撑、星铁矿、轨道和矿灯',6],['pass-core','熔核腹地','火山深处的锻炉遗迹，熔岩沟槽、黑曜石地台和巨大古炉',8]],
    fen:[['fen-temple','沉没神殿内殿','半沉神殿内殿，破损王座、星纹石柱、浅黑水和蓝色长灯',5],['fen-crypt','王陵深层','王陵地下石室，雕刻石棺、刻名银币、壁画和冷蓝烛光',7],['fen-seal','黑水封印庭','沼泽中的王朝封印庭，环形祭台、断桥、黑水与归灯',9]],
    coast:[['coast-reef','潮间礁道','退潮海岸礁道，潮池、漂流木、贝壳和海雾灯塔',4],['coast-hold','沉船货舱','倾斜但可通行的古老沉船货舱，木梁、破帆、箱子与蓝光',6],['coast-deck','无旗船甲板','雾中幽灵帆船的宽敞甲板，主桅、舵轮、海灯和月色浪花',8]]
  };
  const owners={town:'mira',wood:'sylvi',pass:'toren',fen:'eira',coast:'lian'};
  const questNames={town:'城墙下的归路',wood:'古根的最后一封信',pass:'白火商路',fen:'被抹去的守门人',coast:'潮水带回的名字'};
  const roomDetails={
    chapel:'石砌礼拜堂，星形祭台、长烛、彩绘玻璃、木祷告席和祷告簿',inn:'温暖旅店，石壁炉、长桌、旅客名册、吧台、木梁与旅行行囊',guildhall:'公会大厅，委托板、边境地图桌、盾牌陈列与卷轴柜',clocktower:'钟塔机芯室，铜齿轮、星盘、长望远镜与十三槽星图台',market:'杂货店，整齐的药瓶货架、干粮、账簿、木柜台与铜钥匙',
    'forest-hut':'森林药师木屋，干燥草束、药箱、窗外树根、野外手记与药圃','waystation':'峡道驿站，行军铺位、路线板、矿车零件、旅行装备与炉火','grayforge':'灰炉锻坊，明亮熔炉、星铁砧、冷却槽、工具墙与半成品铠甲','lighthouse':'灯塔上层，巨大灯镜、螺旋石梯、航海图、浸水信与海面窗口','fisher-hut':'渔人木屋，鱼网、潮位尺、木桶、晒鱼架与修网桌',
    'royal-hall':'王城接待厅，磨损王座、金边地毯、王朝家谱、银印与长窗','artisan-quarter':'蓝瓦街区的公共工匠厅，彩色布料、木雕、乐器、壁画和喷泉窗景','star-academy':'星术学院教室，星空穹顶、书架、玻璃天球、课桌与符文黑板','alchemist-lab':'炼金实验室，玻璃蒸馏器、青蓝药液、药草、铜管与试剂柜','town-stables':'马厩内部，木隔栏、干草、马具、饮水槽、缰绳与饲料袋','north-gate':'城门守卫室，箭孔、值勤簿、训练盾、钥匙架、城门绞盘',
    'windmill-farm':'风车磨坊，巨大木齿轮、磨盘、麦袋、面粉、农具和日光窗','ridge-barracks':'灰盾兵营，整齐床铺、盾架、战术沙盘、旗帜和训练装备','deep-mine':'玄铁矿场工作厅，矿脉、选矿台、木支撑、矿灯、轨道与铁镐','ember-fortress':'熔火旧堡议事厅，黑曜石长桌、停战卷轴、红色火盆、破旗与石柱','violet-rift':'紫晶地牢档案室，紫水晶、古老书架、无眠档案和锁链','cloud-observatory':'云上观星城大厅，星路仪、天球、蓝金拱门、书桌和云海窗景','tide-harbor':'港口仓储接待厅，货箱、航海图、船票、绳网、木柜台与泊船窗景'
  };
  const old=window.BuildingSystem,rooms={},scenes={},manifests=[];
  const makeProp=(id,name,x,y,action,detail)=>({id,name,x,y,action,detail,w:.65,d:.55});
  for(const b of old.all.filter(b=>b.interior)){
    const r=old.interior(b.id);if(r.procedural){rooms[b.id]=r;scenes[r.id]=r;continue;}r.sceneId='room-'+b.id;r.columns=10;r.rows=10;r.background='assets/expansion/scenes/'+r.sceneId+'.webp';r.exit={x:9,y:9};
    r.props=r.props.map(p=>({...p,action:'service',w:.65,d:.55}));
    r.props.push(makeProp('supplies-cache','旅行储物柜',7.7,5.4,'cache','柜中保存着居民为旅人准备的一份补给，首次取用获得材料和干粮。'),makeProp('workstation','工作与休息台',3.1,6.6,'restore','每日可整理装备并恢复生命与法力，台旁的记录补充这座建筑的往事。'));
    r.occluders=[{x:1.1,y:6.7,w:1.1,d:.65}];rooms[b.id]=r;scenes[r.sceneId]={...r,id:r.sceneId,place:b.place,kind:'room',title:r.title};
    manifests.push({id:r.sceneId,name:b.name,description:roomDetails[b.id],kind:'room'});
  }
  for(const [place,list]of Object.entries(routes))list.forEach(([id,title,description,level],index)=>{
    const s={id,sceneId:id,place,index,title,description,level,kind:'submap',columns:10,rows:10,background:'assets/expansion/scenes/'+id+'.webp',exit:{x:9,y:9},occupantKey:id,room:'ruin',props:[makeProp('survey','调查路线线索',4.5,1.9,'survey','查验这里的旧记号，记录归路，并开启下一段探索。'),makeProp('supplies-cache','遗留旅行箱',2.3,5.5,'cache','首次开启可得到金币、材料和旅行补给。'),makeProp('choice','旅途抉择',7.3,3.7,'event','这里留下两种不同的处理办法，你的选择将改变居民关系与世界倾向。'),makeProp('encounter',index===2?'区域守卫入口':'警戒中的敌群',6.7,7,'encounter','观察敌方招式，准备后可交战。'),...(index<2?[makeProp('next','通往下一处',8.5,5.8,'portal','循着调查到的记号前往下一处探索。')]:[])],occluders:[{x:1.2,y:7,w:1,d:.6}]};scenes[id]=s;manifests.push({id,name:title,description,kind:'submap'});
  });
  for(const [bid,sid]of [['sunken-temple','fen-temple'],['royal-crypt','fen-crypt']]){const b=old.get(bid);b.interior=sid;scenes[sid].buildingId=bid;scenes[sid].service=b.action;scenes[sid].props.push(makeProp('royal-service',bid==='sunken-temple'?'神殿誓言':'王陵记录',2.5,2.5,'service','执行原有的王朝调查行动，推进相关委托。'));rooms[bid]={...scenes[sid],buildingId:bid,occupantKey:sid,service:b.action};}
  for(const scene of Object.values(scenes))if(!scene.procedural)window.SceneLayouts.apply(scene);
  for(const id of Object.keys(rooms))rooms[id]=scenes[rooms[id].sceneId];
  old.interior=id=>rooms[id]?JSON.parse(JSON.stringify(rooms[id])):null;
  const quests=Object.fromEntries(Object.entries(routes).map(([place,list])=>[place,{id:'expedition-'+place,name:questNames[place],npc:owners[place],steps:list.map(v=>'调查'+v[1]+'的路线线索'),reward:{xp:450+window.GameData.PLACES[place].danger*90,gold:75+window.GameData.PLACES[place].danger*20}}]));
  function canEnter(s,id){const r=scenes[id];return!!r&&r.place===s.place&&(r.kind==='room'||r.buildingId&&s.exploration.buildings.includes(r.buildingId)||r.index===0||s.sceneProgress?.[routes[r.place][r.index-1][0]+':survey']);}
  function normalize(s){s.sceneProgress={...(s.sceneProgress||{})};s.expeditions={...(s.expeditions||{})};s.sceneVisits=[...new Set((Array.isArray(s.sceneVisits)?s.sceneVisits:[]).filter(id=>scenes[id]))];for(const k of Object.keys(s.expeditions))if(!quests[k])delete s.expeditions[k];else {const q=s.expeditions[k]||{};s.expeditions[k]={stage:Math.max(0,Math.min(3,Number(q.stage)||0)),done:!!q.done};}s.location={sceneId:null,...window.WorldRegions.spawn(s.place),zoom:1,stack:[],...(s.location||{})};if(s.location.sceneId&&!canEnter(s,s.location.sceneId))s.location.sceneId=null;Object.assign(s.location,window.WorldRegions.safe(s.place,s.location.x,s.location.y,s.location.sceneId));s.location.zoom=Math.max(1,Math.min(1.75,Number(s.location.zoom)||1));s.location.stack=(Array.isArray(s.location.stack)?s.location.stack:[]).slice(-20).filter(x=>x&&(!x.sceneId||scenes[x.sceneId]?.place===s.place)).map(x=>({sceneId:x.sceneId||null,...window.WorldRegions.safe(s.place,x.x,x.y,x.sceneId),zoom:Math.max(1,Math.min(1.75,Number(x.zoom)||1))}));}
  function progress(s,id,h){const r=scenes[id],key=id+':survey';if(!r||r.kind!=='submap'||s.sceneProgress[key])return;s.sceneProgress[key]=true;const q=s.expeditions[r.place]||(s.expeditions[r.place]={stage:0,done:false});while(q.stage<3&&s.sceneProgress[routes[r.place][q.stage][0]+':survey'])q.stage++;if(q.stage===3&&!q.done){q.done=true;const def=quests[r.place];s.player.xp+=def.reward.xp;s.player.gold+=def.reward.gold;window.GrowthSystem.addAffinity(s,def.npc,10);h.levelUp(s);h.log(s,'调查「'+def.name+'」完成，五地归路多了一段新的记录。');}}
  const originalInside=window.NPCSystem.inside;window.NPCSystem.inside=id=>['fen-temple','fen-crypt'].includes(id)?[{...window.NPCSystem.all[id==='fen-temple'?'eira':'silent-archivist'],id:id==='fen-temple'?'eira':'silent-archivist',x:4.5,y:3.4}]:originalInside(id);
  const entrances={'north-gate':'town-wall','violet-rift':'town-drain',guildhall:'town-trial','forest-hut':'wood-trail','moss-shrine':'wood-roots','moon-well':'wood-well','caravan-yard':'pass-path','deep-mine':'pass-mine','ember-fortress':'pass-core','sunken-temple':'fen-temple','royal-crypt':'fen-crypt','moon-shrine':'fen-seal','tide-harbor':'coast-reef','wreck-shrine':'coast-hold',lighthouse:'coast-deck'};
  for(const scene of Object.values(scenes)){const art=window.ArtCatalog?.scenes?.[scene.sceneId];if(art)scene.background=art.url||"assets/art-v2/"+art.file;}
  window.SceneSystem={routes,scenes,rooms,quests,manifests,entrances,get:id=>scenes[id]||null,canEnter,normalize,progress,route:place=>(routes[place]||[]).map(r=>scenes[r[0]])};
})();

