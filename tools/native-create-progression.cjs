// Native authoring source for the additive awakening chapter. No web migration.
const fs=require('node:fs'),path=require('node:path');
const base=path.resolve(__dirname,'../godot'),original=JSON.parse(fs.readFileSync(path.join(base,'data/narrative.json')));
const stories={
 hero:{name:'归灯星陨',title:'第十三声的回答',building:'clocktower',color:'#d5b773',element:'astral',kind:'starfall',power:2,art:'sentinel',intro:['米拉把第十三道刻痕留在星图中央。「钟声一直在等待一个名字。你还没有找到过去，但已经替许多人记住了归路。」','旅人把手放在停住的机芯上。齿轮没有转动，掌心却传来微弱的回响。'],clues:[['失名的刻痕','机芯上有一道没有署名的刻痕。你试着写下旅人的名字，刻痕便与周围十二道连成了一圈。'],['归途的星针','星针指向的不是远方，而是镇上每一扇亮着的窗。力量并非失去的记忆，而是你现在愿意守住的东西。']],closing:['第十三声终于与前十二声重合。你没有想起自己的来处，却第一次清楚地知道，自己要走向哪里。','米拉收起星图。「那么，下次钟响时，由我们来回答。」'],desc:'全体敌人受到 2.0 倍星辉伤害，额外削减 1 格架势。'},
 mira:{name:'星轨终章',title:'留白也有名字',building:'clocktower',color:'#b7a1df',element:'astral',kind:'constellation',power:2.2,art:'sorceress',intro:['米拉摊开那张写满名字的旧星图。纸角仍留着一块空白。「我曾经以为，没能写下的名字，就会被星光遗忘。」','她将一支没有墨的笔交给你。「这一次，替我看看留白之外的路。」'],clues:[['反面的笔迹','纸背的旧笔迹与正面的星轨相连。米拉的导师并没有删去那些名字，而是为后来的人留下了位置。'],['空白的星位','星位在月光下显出细密的针孔。每个针孔都是一次重新测量；被留下的空白，原来是新的起点。']],closing:['米拉把最后一段轨迹画向空白。散开的光点同时亮起，像许多相隔很远的人，终于看见了同一片夜空。','「这不是最后一页。」她笑着说，「只是我终于敢把下一页翻开。」'],desc:'全体敌人受到 2.2 倍星辉伤害，并获得易伤，持续 2 次行动。'},
 toren:{name:'不坠灰盾',title:'第四道刻痕',building:'grayforge',color:'#c59d6a',element:'physical',kind:'bastion',power:0,art:'commander',intro:['托伦把灰盾放在铁砧边。三道裂痕已经补好，他却迟迟没有伸手取回。「修好盾，不代表我就不会再失去谁。」','炉火照亮他的指节。你问他，这一次想守住什么。'],clues:[['修补的铆钉','每一枚新铆钉都避开了旧裂痕。锻师没有抹去失败，而是让盾学会承受下一次撞击。'],['未刻的盾沿','盾沿留着第四道刻痕的位置。托伦说，这里不会再刻失去的名字，只刻仍在同行的人。']],closing:['铁砧前的回声化作一圈温暖的光。托伦抬盾，身后的影子不再散开。','「我无法答应谁都不会受伤。但这一次，我会先站在前面。」'],desc:'全队获得最大生命 25% 的护盾，托伦嘲讽敌人，持续 2 次行动。'},
 sylvi:{name:'翠野长歌',title:'药方之外的春天',building:'forest-hut',color:'#91bd91',element:'holy',kind:'verdant',power:0,art:'treant',intro:['希薇在祖母的药方旁放下一株刚发芽的草。「药方写得很完整，可她没有告诉我，森林不再唱歌时该怎么办。」','窗外的叶片轻轻碰在一起，像有人在等她接上未完的句子。'],clues:[['新芽的注记','药方最后一页写着：若旧叶落尽，先照顾新芽。祖母记录的不是永远有效的答案，而是继续观察的办法。'],['根系的和声','地下根系避开石块，在更深处重新汇合。希薇听见的不是一棵树的歌，而是许多生命互相扶持的声音。']],closing:['希薇把药方合上，第一次没有照着谱子唱。绿光沿着脚边的草叶传开，疲惫的呼吸渐渐平稳。','「原来祖母把最后一味药留给了我。」她说，「让它继续生长。」'],desc:'全队恢复最大生命 25%，获得每次行动恢复最大生命 10% 的再生，持续 2 次行动。'},
 'ridge-scout':{name:'归路无影',title:'留下脚印的人',building:'ridge-barracks',color:'#879fca',element:'physical',kind:'shadow',power:3.5,art:'bandit',intro:['夜岚把旧岗哨的路线图翻到背面。那一夜逃离的路线，他记得比任何人都清楚。','「我跑得最快。」他说，「可最快的人，也应该知道该在什么时候停下来。」'],clues:[['反向的路标','地图上有一支指向身后的箭头。那不是撤退路线，而是为折返的人留下的标记。'],['熄灭的火盆','火盆底部还压着一截没有烧尽的引线。夜岚终于承认，自己一直保留着重新点燃它的办法。']],closing:['影子越过旧岗哨，又在伙伴身旁停下。夜岚在路线图上补了一条新的线。','「来时不必看见我。」他说，「归去时，我会让你知道我在。」'],desc:'无视前后排选择一名敌人，造成 3.5 倍物理伤害，随后附加破甲 2 次行动。'},
 eira:{name:'万灯归航',title:'没有姓名的灯',building:'moon-shrine',color:'#eed99b',element:'holy',kind:'dawn',power:0,art:'skeleton',intro:['艾拉将长灯放在祭坛中央。灯下有许多没有署名的银币，像许多尚未归来的人。','「我曾以为守灯，就是站在原地等。」她望向水面，「可灯光也应该走到需要它的人身边。」'],clues:[['水下的灯影','水里映出的灯比祭坛上的更多。有人把微弱的火光传给了下一位旅人，才让这条路一直亮着。'],['未署名的银币','银币背面刻着一句话：请替后来的人留一盏。艾拉不再追问是谁留下它，而是记下了它要去的地方。']],closing:['星形法杖落下一线柔光，祭坛上每一处暗影都浮起小小的灯。艾拉的手不再颤抖。','「名字可以慢慢找。」她说，「先让他们回家。」'],desc:'存活队友恢复最大生命 35%并净化，另复活站位最靠前的一名倒地队友至 30%生命。'},
 alchemist:{name:'青瓶新生',title:'最后一滴的刻度',building:'cloud-observatory',color:'#79b9b3',element:'poison',kind:'elixir',power:1.6,art:'serpent',intro:['瑟琳把青瓶举到星路仪前。药液在瓶壁上留下一道比过去更浅的刻度。','「我一直想做出永不失效的药。」她停顿了一下，「后来发现，真正需要改变的，是我对失败的用法。」'],clues:[['重新校准的滴管','滴管上被划去的不是错误，而是旧药液在不同温度下的变化。瑟琳开始把每一次失效写成下一次的条件。'],['瓶底的星屑','星屑并未溶解，而是为药液保留了重新反应的起点。最后一滴不该用于证明完美，而该用于开启新的配方。']],closing:['青瓶里的光分成两道：一道封住敌人的毒息，一道回到同伴疲惫的掌心。瑟琳在标签上写下新的日期。','「这次不是最后一瓶。」她说，「我们还有很多试验要做。」'],desc:'全体敌人受到 1.6 倍毒伤并中毒 2 次行动，全队恢复最大 MP 的 10%。'}
};
const sites={
 guildhall:{type:'commission',name:'边境药草清单',scene:'room-guildhall',detail:[['补给回执','回执上的药草数量总比货单多一小把，那是镇民留给值夜人的份额。'],['旧公会徽','徽章边缘被摸得发亮。公会将已经完成的委托装订成册，供后来的人找到自己的第一条路。']],material:'herb',amount:3,gold:18,xp:20},
 clocktower:{type:'awakening',name:'钟声与星轨',scene:'room-clocktower',detail:[['回声校准盘','校准盘上十二道刻度指向不同街巷，第十三道留给归来的人。'],['旅人留名簿','有人写下全名，有人只画了一盏灯。米拉把每一页都保存了下来。']]},
 'forest-hut':{type:'research',name:'草木的新一页',scene:'room-forest-hut',detail:[['晾药竹筛','药草依采摘时辰分开晾晒，清晨的叶片仍带着细小露痕。'],['生长札记','新叶的边缘被画了三遍，每一次都比前一次舒展。']],xp:15},
 'moss-shrine':{type:'clue',name:'根系下的星纹',scene:'wood-roots',detail:[['覆苔的星槽','苔藓沿着星槽生长，细根却在第三条岔路前向东折返。'],['落叶路签','路签上的叶片分别来自三棵不同的树。把它们排好，便能找到通往根系深处的路。']]},
 grayforge:{type:'order',name:'锻坊首份订单',scene:'room-grayforge',detail:[['交货木牌','木牌只记材料和手艺，不记讨价还价。托伦说，守路的人需要一把可靠的刀。'],['淬火水纹','水面每次平静后都会留下一圈淡金色粉末，那是星铁冷却的痕迹。']],recipe:'trailblade',xp:10},
 'ridge-barracks':{type:'training',name:'灰盾演练',scene:'room-ridge-barracks',detail:[['练习盾靶','盾靶上标着护卫站位，最深的凹痕落在通向同伴的一侧。'],['换岗铃绳','铃绳末端编着不同颜色的结，即使雾中看不清人，也能认出返回的小队。']]},
 'moon-shrine':{type:'awakening',name:'灯誓的回响',scene:'fen-seal',detail:[['净水灯盏','水面上每一盏灯都系着细线，风起时仍不会离开祭坛太远。'],['祈愿石片','石片没有刻下请求，只刻着一条能让旅人平安返回的路。']]},
 'cloud-observatory':{type:'research',name:'星路反应记录',scene:'room-cloud-observatory',detail:[['星屑温标','温标记录星屑明暗与药液变化的关系，最下面一格被瑟琳改了又改。'],['折光棱镜','棱镜把同一束光分开，又在仪器另一侧重新汇合。']],xp:15},
 lighthouse:{type:'clue',name:'灯镜指向的归帆',scene:'room-lighthouse',detail:[['灯镜转轴','转轴停在海图的缺口上，照见一段被潮水藏起的甲板。'],['潮汐刻线','刻线旁写着：低潮时顺风而行，归来时沿灯光靠岸。']]},
 'tide-harbor':{type:'commission',name:'归帆修缮清单',scene:'room-tide-harbor',detail:[['修缮货单','货单上最先勾去的是舷灯。归帆港的人相信，船回来时应该先看见家的光。'],['系缆铜环','铜环被绳索磨出温润的凹槽，新旧船只都在这里留下过重量。']],material:'ore',amount:2,gold:14,xp:20},
 'city-academy-3':{type:'training',name:'天球塔 · TP 沙盘',scene:'room-city-academy-3',detail:[['共鸣星仪','星仪将行动、受击与架势击破转成可见的共鸣。充满 100 TP 后，按 Q 选择大招，再按 Enter 确认。'],['试炼沙盘','沙盘模拟六级队伍，离开时完整归还进入前的队伍与 TP。']]},
 'city-faith-3':{type:'archive',name:'守灯会馆 · 觉醒档案',scene:'room-city-faith-3',detail:[['七枚空印','七枚纹章分别等待自己的故事，力量不会因为名字相同而属于另一个人。'],['归灯书页','书页记录已经完成的觉醒。曾经说过的话不会重新成为委托，却会成为旅途的一部分。']]}
};
// Preserve the existing interiors and append new details without reordering old props.
for(const [id,site] of Object.entries(sites)){
 if(!original.scenes[site.scene]&&id!=='city-academy-3'&&id!=='city-faith-3'){
  const fallback=Object.entries(original.scenes).find(([k,v])=>v.buildingId===id||v.occupantKey===id);
  if(!fallback)throw Error('Missing interior for '+id);site.scene=fallback[0];
 }
 site.building=id;site.place=original.buildings.find(b=>b.id===id).place;
 site.details=site.detail.map(([name,detail],i)=>({id:'detail-'+id+'-'+i,name,detail,x:i?6.6:2.1,y:7.2,w:0.8,d:0.6,action:'read',building:id}));delete site.detail;
}
for(const [id,s] of Object.entries(stories)){
 s.id=id;s.scene=sites[s.building].scene;
 s.clues=s.clues.map(([name,detail],i)=>({id:'awakening-'+id+'-'+i,name,detail,x:i?6.6:2.1,y:id==='hero'?6.0:4.2,w:0.8,d:0.6,action:'read',awakening:id,clue:i}));
}
const rooms={};
for(const [id,style] of [['city-academy-3','academy'],['city-faith-3','church']]){
 const reference=original.scenes['room-city-'+(style==='academy'?'academy-0':'faith-0')];
 rooms['room-'+id]={...reference,id:'room-'+id,title:id==='city-academy-3'?'天球塔 · 星仪室':'守灯会馆 · 归灯藏室',buildingId:id,occupantKey:id,place:'city',procedural:true,style,props:[],collisions:[]};
}
const data={revision:1,tp:{maximum:100,actionGain:20,hitGain:10,hitRoundCap:20,breakGain:10},ultimates:stories,buildings:sites,rooms};
fs.writeFileSync(path.join(base,'data/progression.json'),JSON.stringify(data,null,2)+'\n');
console.log('Authored 7 awakening stories, 12 building services, 24 details and 2 rooms.');
