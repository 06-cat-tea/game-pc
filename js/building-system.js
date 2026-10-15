(() => {
  "use strict";
  const buildings = {
    town: [
      { id:"chapel", name:"晨星礼拜堂", kind:"chapel", x:3, y:2, w:2, d:2, h:94, action:"chapel", interior:"chapel", description:"守灯祭司在这里照看镇上的长烛与旅人。" },
      { id:"inn", name:"晨星旅店", kind:"inn", x:3, y:7, w:3, d:2, h:84, action:"tavern", interior:"inn", description:"酒馆里总有人带来地图边缘的新消息。" },
      { id:"guildhall", name:"边境公会", kind:"guild", x:8, y:5, w:3, d:2, h:116, action:"guild", interior:"guild", description:"公会的公告板记录着边境上的委托。" },
      { id:"clocktower", name:"晨星钟塔", kind:"tower", x:13, y:2, w:2, d:2, h:188, talk:"mira", interior:"tower", description:"米拉在钟塔下等候，星图的线索从这里开始。" },
      { id:"market", name:"行省杂货铺", kind:"shop", x:16, y:7, w:2, d:2, h:75, action:"market", interior:"market", description:"补充药剂、干粮和旅行装备。" }
    ],
    wood: [
      { id:"forest-hut", name:"林间小屋", kind:"hut", x:3, y:6, w:3, d:2, h:75, action:"forage", interior:"hut", description:"林地医者留下的草药和手记仍在屋内。" },
      { id:"moss-shrine", name:"苔痕遗迹", kind:"ruin", x:11, y:3, w:4, d:2, h:100, action:"ruins", description:"石碑上残留着古老的银叶文字。" },
      { id:"moon-well", name:"月井", kind:"well", x:16, y:9, w:2, d:2, h:32, action:"well", description:"井水映出白昼里看不见的星群。" }
    ],
    pass: [
      { id:"waystation", name:"峡道驿站", kind:"inn", x:3, y:9, w:3, d:2, h:72, action:"escort", interior:"waystation", description:"矿车在这里整队，车夫正寻找护卫。" },
      { id:"grayforge", name:"灰炉锻坊", kind:"forge", x:9, y:5, w:3, d:2, h:92, action:"forge", interior:"forge", description:"炉火可以锻造边境上少见的装备。" },
      { id:"caravan-yard", name:"矿车营地", kind:"camp", x:15, y:9, w:3, d:2, h:50, action:"mine", description:"矿工和车夫在此交换山脉情报。" }
    ],
    fen: [
      { id:"sunken-temple", name:"沉没神殿", kind:"temple", x:8, y:3, w:4, d:3, h:124, action:"temple", description:"神殿门后的王朝守卫仍未安息。" },
      { id:"royal-crypt", name:"王陵侧室", kind:"crypt", x:15, y:8, w:3, d:2, h:80, action:"crypt", description:"石棺的铭文记录着没有名字的人。" },
      { id:"moon-shrine", name:"净水祭坛", kind:"shrine", x:4, y:5, w:2, d:2, h:56, action:"purify", description:"祭坛上的灯火可以驱散黑水。" }
    ],
    coast: [
      { id:"lighthouse", name:"风葬灯塔", kind:"lighthouse", x:3, y:3, w:2, d:2, h:176, action:"lighthouse", interior:"lighthouse", description:"登上塔顶，修复旧镜并追寻无旗之船。" },
      { id:"fisher-hut", name:"潮汐渔屋", kind:"hut", x:11, y:8, w:3, d:2, h:70, action:"fish", interior:"fisher-hut", description:"渔屋门口的水桶里放着当天的收获。" },
      { id:"wreck-shrine", name:"沉船祭标", kind:"ruin", x:16, y:10, w:2, d:2, h:38, action:"wreck", description:"礁石旁的铜牌标出了沉船位置。" }
    ]
  };
  const rooms = {
    chapel:{title:"晨星礼拜堂内室",room:"chapel",description:"长烛、祷告席和褪色的星图共同守着这座小礼拜堂。",props:[{id:"altar",name:"晨星祭台",x:5,y:1.8,detail:"烛火没有摇晃，烛芯里却映出一片陌生的星空。"},{id:"prayer-book",name:"祷告簿",x:2,y:3.2,detail:"最近一页写着：第十三声钟响时，请替无名者留一盏灯。"}]},
    inn:{title:"晨星旅店内室",room:"inn",description:"木梁、长桌与炉火组成了边境旅人短暂的归处。",props:[{id:"hearth",name:"壁炉",x:2,y:2,detail:"火焰把湿斗篷烘干，也把旅人的影子投向墙上的旧地图。"},{id:"guestbook",name:"旅客名册",x:7,y:3,detail:"几名旅客在同一天离开，目的地一栏都写着灰炉峡道。"}]},
    guild:{title:"边境公会内室",room:"guild",description:"委托卷轴、边境地图和一块磨损的木质公告板挤满了房间。",props:[{id:"noticeboard",name:"委托公告板",x:7,y:2.2,detail:"新的委托标记着被雾封住的古道。公会印章仍未干透。"},{id:"map-table",name:"边境地图",x:3,y:4,detail:"地图上有一段被反复擦除的路线，终点正是沉没神殿。"}]},
    tower:{title:"钟塔内室",room:"tower",description:"齿轮和星盘缓慢转动，墙上的刻痕记录着钟声的偏差。",props:[{id:"star-chart",name:"星图台",x:6.6,y:2,detail:"星图上有十三个凹槽，第十三颗星的形状像一座沉没的城。"},{id:"clockwork",name:"钟塔机芯",x:2.5,y:3.2,detail:"齿轮每转一圈便停顿一下，像是在等待一只不存在的指针。"}]},
    shop:{title:"杂货铺内室",room:"shop",description:"货架按旅途所需分类，柜台旁挂着一串磨亮的铜钥匙。",props:[{id:"supply-shelf",name:"旅行货架",x:2,y:2.3,detail:"药剂、灯油和干粮都贴着清楚的价格标签。"},{id:"ledger",name:"赊账簿",x:7,y:3.2,detail:"账簿里有一笔旧账：有人用一枚王朝银币换走了灯塔镜片。"}]},
    hut:{title:"林间小屋内室",room:"hut",description:"干燥草束、木药箱和一扇朝向树根的窗户让屋内安静而温暖。",props:[{id:"herb-rack",name:"草药架",x:2,y:2.2,detail:"银脉草被细心捆好，叶脉在暗处透出淡淡的蓝光。"},{id:"field-notes",name:"野外手记",x:7,y:3,detail:"手记称，森林深处的古根正在重复一段被遗忘的名字。"}]},
    waystation:{title:"峡道驿站内室",room:"inn",description:"驿站把休息铺位、车队路线图和护送装备放在同一间屋里。",props:[{id:"route-board",name:"商路板图",x:7,y:2.2,detail:"矿车路线在峡道拐角处中断，旁边留下新鲜的黑色爪痕。"},{id:"travel-bunk",name:"行军铺位",x:2,y:3.4,detail:"铺位旁放着一只空药盒，像是有人刚刚匆忙出发。"}]},
    forge:{title:"灰炉锻坊内室",room:"forge",description:"熔炉、铁砧和冷却槽把锻造的每一步清晰地留在空气里。",props:[{id:"anvil",name:"星铁砧台",x:6.6,y:3.2,detail:"砧面留着星形凹痕，正好能嵌入一枚星屑。"},{id:"furnace",name:"灰炉熔炉",x:2,y:2.4,detail:"炉火的中心呈现灰白色，里面似乎混入了王朝旧炉的火种。"}]},
    lighthouse:{title:"风葬灯塔内室",room:"tower",description:"狭窄的石塔内盘旋着楼梯，旧灯镜把海面的光斑折成细线。",props:[{id:"lens",name:"旧灯镜",x:6.4,y:2.2,detail:"镜片缺了一角，缺口的方向正指向雾中的无旗船。"},{id:"captain-letter",name:"浸水的信",x:2.3,y:3.3,detail:"信里只剩一句话：若第十三声响起，不要让灯塔熄灭。"}]},
    "fisher-hut":{title:"潮汐渔屋内室",room:"hut",description:"渔网、木桶和潮位刻尺将每日的海况留在了屋内。",props:[{id:"tide-chart",name:"潮位刻尺",x:6.5,y:2.1,detail:"刻度显示潮水曾在午夜倒流，正好露出了沉船祭标。"},{id:"fishing-net",name:"旧渔网",x:2,y:3.2,detail:"网眼里缠着一小片王朝帆布和一枚没有船旗的铜扣。"}]}
  };
  const expansion=window.WorldContent;
  for(const [place,list] of Object.entries(expansion.additions)){
    buildings[place].push(...list.map(b=>({...b,kind:b.asset,h:b.asset==="castle"?170:110})));
    for(const b of list)rooms[b.interior]={title:b.name+"内室",room:["castle","gate","barracks"].includes(b.asset)?"guild":b.asset==="alchemy"?"hut":b.asset==="demon-fortress"?"forge":b.asset==="sky-city"||b.asset==="academy"?"tower":"inn",description:b.description,props:[{id:"local-record",name:b.name+"记录台",x:2.5,y:2.5,detail:b.description+" 这里留下当地居民的工作与旅行记录。"},{id:"service-desk",name:"服务台",x:6.7,y:2.3,detail:expansion.serviceNames[b.action.replace("world:","")]+"，与此处居民共用相同的行动规则。"}],service:b.action};
  }
  buildings.city=window.RoyalCity.buildings;Object.assign(rooms,window.RoyalCity.rooms);
  for(const list of Object.values(buildings))for(const b of list){b.asset=b.asset||expansion.existingAssets[b.id]||"ruins";b.place=Object.keys(buildings).find(k=>buildings[k].includes(b));}
  rooms.market=rooms.shop;rooms["forest-hut"]=rooms.hut;
  const interiors=Object.fromEntries(Object.entries(buildings).flatMap(([,items])=>items.filter(b=>b.interior).map(b=>[b.id,{...rooms[b.interior],buildingId:b.id,occupantKey:b.interior}])));
  for(const b of buildings.town)if(window.ArtV3Catalog?.buildings["town-"+b.id])b.artId="town-"+b.id;
  const all = Object.values(buildings).flat();
  window.WorldLayout?.applyBuildings(all);
  window.BuildingSystem = {
    all,
    at: biome => (buildings[biome] || []).map(item => ({...item})),
    get: id => all.find(item => item.id === id) || null,
    interior: id => interiors[id] ? {...interiors[id],props:interiors[id].props.map(p=>({...p}))} : null
  };
})();
