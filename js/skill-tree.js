(() => {
  "use strict";
  const jobs = {
    ranger:{name:"游侠",desc:"以精准、机动和野外生存见长。",branches:{precision:"精准射击",fieldcraft:"荒野生存",mobility:"迅捷身法"}},
    arcanist:{name:"星术师",desc:"用星辉改写战场节奏，专精法力与爆发。",branches:{starfire:"星火术式",warding:"星界守护",fate:"命运编织"}},
    warden:{name:"守誓者",desc:"守住阵线、承受伤害，并把同伴带回战场。",branches:{oath:"铁誓之路",bastion:"坚壁守护",rally:"战阵号令"}}
  };
  const skills = {
    piercing:{name:"穿林箭",job:"ranger",branch:"precision",tier:1,cost:1,level:2,kind:"active",mp:10,desc:"精准射击造成高额伤害。",effect:"damage",power:1.75,requires:[]},
    fieldcraft:{name:"荒野本能",job:"ranger",branch:"fieldcraft",tier:1,cost:1,level:2,kind:"passive",desc:"营火恢复提高 15%。",effect:"forage",requires:[]},
    lastArrow:{name:"终末箭雨",job:"ranger",branch:"precision",tier:2,cost:2,level:4,kind:"active",mp:20,desc:"连续箭雨，对强敌造成巨额伤害。",effect:"damage",power:2.5,requires:["piercing"]},
    hawkeye:{name:"鹰眼校准",job:"ranger",branch:"precision",tier:3,cost:2,level:6,kind:"passive",desc:"暴击率提高 6%。",effect:"crit",value:.06,requires:["lastArrow"]},
    herbalLore:{name:"草木识途",job:"ranger",branch:"fieldcraft",tier:2,cost:1,level:4,kind:"passive",desc:"采集行动额外获得草药。",effect:"herbBonus",requires:["fieldcraft"]},
    predatorMark:{name:"猎痕标记",job:"ranger",branch:"fieldcraft",tier:3,cost:2,level:6,kind:"active",mp:12,desc:"标记敌人并造成强化伤害，施加 3 回合易伤（受伤 +25%）。",effect:"damage",power:2.1,requires:["herbalLore"]},
    quickstep:{name:"轻身步",job:"ranger",branch:"mobility",tier:1,cost:1,level:2,kind:"passive",desc:"基础攻击提高 1 点。",effect:"atk",value:1,requires:[]},
    evasiveShot:{name:"掠影射击",job:"ranger",branch:"mobility",tier:2,cost:1,level:4,kind:"active",mp:14,desc:"迅速射击并降低本回合受到的伤害。",effect:"evasive",power:1.5,requires:["quickstep"]},
    windrunner:{name:"逐风者",job:"ranger",branch:"mobility",tier:3,cost:2,level:6,kind:"passive",desc:"暴击率提高 4%，生命上限提高 8。",effect:"windrunner",requires:["evasiveShot"]},

    starfall:{name:"星坠",job:"arcanist",branch:"starfire",tier:1,cost:1,level:2,kind:"active",mp:14,desc:"召来星火打击敌人，造成高额伤害和 3 回合灼烧。",effect:"damage",power:2.05,requires:[]},
    manaWell:{name:"法力泉涌",job:"arcanist",branch:"warding",tier:1,cost:1,level:2,kind:"passive",desc:"法力上限提高 20 点。",effect:"mana",value:20,requires:[]},
    astralSeal:{name:"星界封印",job:"arcanist",branch:"starfire",tier:2,cost:2,level:4,kind:"active",mp:22,desc:"封印目标并造成伤害，本回合不受反击；冷却 3 回合。",effect:"seal",power:1.5,requires:["starfall"]},
    meteorScript:{name:"流星术式",job:"arcanist",branch:"starfire",tier:3,cost:2,level:6,kind:"active",mp:26,desc:"召来流星造成毁灭性伤害。",effect:"damage",power:3,requires:["astralSeal"]},
    starWard:{name:"星幕护体",job:"arcanist",branch:"warding",tier:2,cost:1,level:4,kind:"passive",desc:"防御提高 2 点。",effect:"def",value:2,requires:["manaWell"]},
    astralAegis:{name:"星界屏障",job:"arcanist",branch:"warding",tier:3,cost:2,level:6,kind:"active",mp:20,desc:"恢复生命、清除中毒与灼烧，并削弱敌人反击。",effect:"heal",power:1,requires:["starWard"]},
    omenRead:{name:"观星预兆",job:"arcanist",branch:"fate",tier:1,cost:1,level:2,kind:"passive",desc:"暴击率提高 3%。",effect:"crit",value:.03,requires:[]},
    fateThread:{name:"命运丝线",job:"arcanist",branch:"fate",tier:2,cost:1,level:4,kind:"passive",desc:"攻击提高 2 点，法力上限提高 8 点。",effect:"fateThread",requires:["omenRead"]},
    eclipse:{name:"蚀星仪式",job:"arcanist",branch:"fate",tier:3,cost:2,level:6,kind:"active",mp:24,desc:"以星蚀造成高额伤害并跳过反击；冷却 3 回合。",effect:"seal",power:2.2,requires:["fateThread"]},

    ironOath:{name:"铁誓",job:"warden",branch:"oath",tier:1,cost:1,level:2,kind:"passive",desc:"提高防御与生命上限。",effect:"guard",requires:[]},
    rally:{name:"振奋号令",job:"warden",branch:"rally",tier:1,cost:1,level:2,kind:"active",mp:12,desc:"恢复生命并清除中毒、灼烧，降低本回合伤害。",effect:"heal",power:1,requires:[]},
    bulwark:{name:"不破壁垒",job:"warden",branch:"bastion",tier:2,cost:2,level:4,kind:"active",mp:18,desc:"大幅减轻本回合伤害，并反击。",effect:"wall",power:1.1,requires:["shieldWall"]},
    oathkeeper:{name:"誓约守望",job:"warden",branch:"oath",tier:2,cost:1,level:4,kind:"passive",desc:"防御提高 2 点。",effect:"def",value:2,requires:["ironOath"]},
    lastStand:{name:"终线不退",job:"warden",branch:"oath",tier:3,cost:2,level:6,kind:"passive",desc:"生命上限提高 24 点。",effect:"hp",value:24,requires:["oathkeeper"]},
    shieldWall:{name:"盾墙推进",job:"warden",branch:"bastion",tier:1,cost:1,level:2,kind:"active",mp:10,desc:"盾击并降低受到的伤害，获得持续 2 回合的护盾。",effect:"wall",power:.9,requires:[]},
    guardianLine:{name:"护卫阵线",job:"warden",branch:"bastion",tier:3,cost:2,level:6,kind:"passive",desc:"防御提高 3 点，生命上限提高 10 点。",effect:"guardian",requires:["bulwark"]},
    rallyingCry:{name:"战吼",job:"warden",branch:"rally",tier:2,cost:1,level:4,kind:"active",mp:16,desc:"恢复生命、清除中毒与灼烧，并造成少量伤害。",effect:"healStrike",power:.8,requires:["rally"]},
    sharedVow:{name:"同袍誓言",job:"warden",branch:"rally",tier:3,cost:2,level:6,kind:"passive",desc:"生命上限提高 12 点，队伍支援伤害提高。",effect:"sharedVow",requires:["rallyingCry"]}
  };
  window.SkillTree = { jobs, skills, branches:Object.fromEntries(Object.entries(jobs).map(([id,job])=>[id,job.branches])) };
})();

