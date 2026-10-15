// Exercise real normalization/save/UI cycles, where aggregate HP used to be
// written through the first-enemy setter. Use an isolated browser save.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/');
(async()=>{
  const c={};c.window=c;vm.createContext(c);vm.runInContext(fs.readFileSync('js/battle-system.js','utf8'),c);
  for(const raw of [{hp:1372,maxHp:1274},{hp:0,maxHp:1274},{hp:-5,maxHp:100},{hp:50,maxHp:100}]){
    const b=c.BattleSystem.init({name:'精英',enemies:[{id:'elite',name:'岩甲掘兽',...raw}]});assert.equal(b.enemies[0].hp,Math.max(0,Math.min(raw.hp,raw.maxHp)));assert.equal(b.enemies[0].maxHp,raw.maxHp);
  }
  const checks=['Over-limit HP is repaired, while damage and defeated enemies are preserved'];
  const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true}),p=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];
  p.on('pageerror',e=>errors.push(e.message));
  const ready=()=>p.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked());
  await p.goto(url);await ready();await p.locator('[data-command=continue]').click();await ready();
  const invariants=await p.evaluate(()=>{
    const result=[];
    for(const count of [1,2,3]){
      const s=AshenGame.getState();s.battle=BattleSystem.init({name:'岩甲掘兽',hp:300,maxHp:300,power:3,round:0,enemies:Array.from({length:count},(_,i)=>({id:'health-'+i,name:i?'白火矿巫':'岩甲掘兽',hp:120-i*30,maxHp:150-i*20,power:3,elite:true}))});
      const snapshot=()=>s.battle.enemies.map(e=>({hp:e.hp,maxHp:e.maxHp})),before=snapshot();
      for(let i=0;i<20;i++)AshenGame.normalize(s);
      result.push({count,before,after:snapshot(),total:s.battle.hp,max:s.battle.maxHp});
      const parsed=JSON.parse(JSON.stringify(s));parsed.battle.hp=99999;parsed.battle.maxHp=99999;AshenGame.normalize(parsed);result.push({count,before,after:parsed.battle.enemies.map(e=>({hp:e.hp,maxHp:e.maxHp})),total:parsed.battle.hp,max:parsed.battle.maxHp});
    }return result;
  });
  for(const row of invariants){assert.deepEqual(row.after,row.before);assert.equal(row.total,row.before.reduce((n,e)=>n+e.hp,0));assert.equal(row.max,row.before.reduce((n,e)=>n+e.maxHp,0));}
  checks.push('Repeated normalization and stale serialized totals preserve individual HP for one, two and three enemies');
  await p.evaluate(()=>{
    const s=AshenGame.getState();s.party.active=[];s.player.maxHp=4000;s.player.hp=4000;s.player.baseDef=100;s.player.baseAtk=10;s.place='pass';s.location={sceneId:null,...WorldRegions.spawn('pass'),zoom:1,stack:[]};
    s.battle={name:'精英血量回归',hp:200,maxHp:200,power:3,round:0,enemies:[{id:'rock',name:'岩甲掘兽',hp:120,maxHp:120,power:3,elite:true},{id:'mage',name:'白火矿巫',hp:80,maxHp:80,power:3}]};
    localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');
  });await ready();
  const enemies=()=>p.evaluate(()=>AshenGame.getState().battle.enemies.map(e=>({hp:e.hp,maxHp:e.maxHp})));
  assert.deepEqual(await enemies(),[{hp:120,maxHp:120},{hp:80,maxHp:80}]);
  for(let i=0;i<8;i++)await p.evaluate(()=>AshenGame.save());assert.deepEqual(await enemies(),[{hp:120,maxHp:120},{hp:80,maxHp:80}]);
  for(let i=0;i<4;i++){
    const before=await enemies();await p.locator('[data-combat=attack]').click();await ready();const after=await enemies();
    assert(after[0].hp<=before[0].hp);if(i===0)assert(after[0].hp<before[0].hp);assert.equal(after[1].hp,before[1].hp);assert.deepEqual(after.map(e=>e.maxHp),[120,80]);
    const saved=await p.evaluate(()=>JSON.parse(localStorage.getItem('ashen-frontier-save-v3-desktop')).battle.enemies.map(e=>({hp:e.hp,maxHp:e.maxHp})));assert.deepEqual(saved,after);
    await p.locator('[data-battle-target=mage]').click();assert.deepEqual(await enemies(),after);await p.locator('[data-battle-target=rock]').click();assert.deepEqual(await enemies(),after);
  }
  const beforeReload=await enemies();await p.reload();await ready();await p.locator('[data-command=continue]').click();await ready();assert.deepEqual(await enemies(),beforeReload);
  checks.push('Attack, autosave, manual save, target switches and page reload never inflate enemy HP or maximum HP');
  await p.evaluate(()=>{const s=AshenGame.getState();s.battle={name:'旧精英存档',hp:1372,maxHp:1274,power:3,round:2,enemies:[{id:'rock',name:'岩甲掘兽',hp:1372,maxHp:1274,power:3,elite:true},{id:'dead',name:'白火矿巫',hp:0,maxHp:80,power:3}]};localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');});await ready();assert.deepEqual(await enemies(),[{hp:1274,maxHp:1274},{hp:0,maxHp:80}]);await p.locator('[data-combat=attack]').click();assert((await enemies())[0].hp<1274);assert.equal((await enemies())[1].hp,0);
  checks.push('Existing 1372/1274 save resumes within HP limits without reviving defeated enemies');
  // Legitimate healer abilities may restore HP, but cannot exceed the cap.
  const healing=await p.evaluate(()=>{const s=AshenGame.getState();s.party.active=[];s.battle=BattleSystem.init({name:'治疗者',round:2,enemies:[{id:'wounded',name:'受伤精英',hp:10,maxHp:100,power:1},{id:'healer',name:'治疗者',hp:100,maxHp:100,power:1,role:'healer'}]});BattleSystem.resolve(s,'potion',{stats:()=>({atk:10,def:100,maxHp:5000,maxMana:100,crit:0}),roll:a=>a,skills:{}});return s.battle.enemies.map(e=>({hp:e.hp,maxHp:e.maxHp}));});assert.equal(healing[0].hp,22);assert(healing.every(e=>e.hp<=e.maxHp));checks.push('Intentional enemy healing remains functional and capped');
  fs.mkdirSync('artifacts',{recursive:true});await p.screenshot({path:'artifacts/battle-health-fixed.png'});assert.deepEqual(errors,[]);await browser.close();fs.writeFileSync('artifacts/battle-health-acceptance-'+(url.startsWith('http')?'http':'file')+'.json',JSON.stringify({passed:true,url,checks,errors},null,2));checks.forEach(x=>console.log('PASS '+x));
})().catch(e=>{console.error(e);process.exit(1);});
