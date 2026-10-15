// Isolated browser saves only; supports file:// and optional static-server URL.
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/');
(async()=>{
  fs.mkdirSync('artifacts',{recursive:true});
  const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
  const page=await browser.newPage({hasTouch:true,isMobile:true,viewport:{width:1280,height:720}}),errors=[],passed=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const test=async(name,fn)=>{await fn();passed.push(name);console.log('PASS '+name);};
  await page.goto(url);await page.waitForFunction(()=>window.AshenGame);await page.locator('[data-command=continue]').click();
  const state=()=>page.evaluate(()=>AshenGame.getState()),base=await state();
  const seed=async mutate=>{const s=JSON.parse(JSON.stringify(base));mutate(s);await page.evaluate(s=>{localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');},s);};
  const meet=async(id,affinity=80)=>page.evaluate(({id,affinity})=>{
    const n=GrowthSystem.npcs()[id],b=BuildingSystem.all.find(b=>{const r=BuildingSystem.interior(b.id);return r&&NPCSystem.inside(r.occupantKey).some(n=>n.id===id);}),s=AshenGame.getState();
    s.battle=null;s.place=n.place||b.place;s.location={sceneId:null,x:10,y:12,zoom:1,stack:[]};s.relationships[id].value=affinity;s.relationships[id].chatDay=s.day;
    localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');if(!n.place)AshenGame.enterBuilding(b.id);AshenGame.talkNPC(id,false);
  },{id,affinity});
  const advanceToChoice=async(id,topic)=>page.evaluate(({id,topic})=>{const started=DialogueSystem.start(id,topic);DialogueSystem.next();DialogueSystem.next();return started;},{id,topic});
  await test('all 66 residents have 198 base and six deep topics, each branch has five valid lines',async()=>{
    const content=await page.evaluate(()=>({ids:Object.keys(GrowthSystem.npcs()),people:DialogueContent.people}));
    assert.equal(content.ids.length,66);assert.deepEqual(Object.keys(content.people).sort(),content.ids.sort());
    let count=0;const intros=new Set();for(const p of Object.values(content.people)){
      assert(p.daily&&p.rumor&&p.past);assert.equal(p.past.min,20);if(p.deep)assert.equal(p.deep.min,40);
      for(const t of Object.values(p)){count++;assert.equal(t.intro.length,2);assert.equal(t.options.length,2);assert(t.end);for(const o of t.options)assert(o.text&&o.reply);assert(!intros.has(t.intro.join('')));intros.add(t.intro.join(''));}
    }assert.equal(count,204);
    for(const id of content.ids){await meet(id);for(const topic of Object.keys(content.people[id])){
      for(const index of [0,1]){
        await page.evaluate(({id,topic})=>{const s=AshenGame.getState();delete s.flags[`dialogue:${id}:${topic}:choice`];localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');}, {id,topic});
        const before=await state();assert(await advanceToChoice(id,topic));
        const result=await page.evaluate(index=>{const chosen=DialogueSystem.choose(index),response=!!document.querySelector('.dialogue-text');DialogueSystem.next();DialogueSystem.next();DialogueSystem.next();return {chosen,response,active:DialogueSystem.reading()};},index);
        assert(result.chosen&&result.response&&!result.active);const after=await state();assert.equal(after.flags[`dialogue:${id}:${topic}:seen`],true);
        assert.equal(after.relationships[id].value,Math.min(100,before.relationships[id].value+(topic==='past'&&index===0?2:0)));
        assert.equal(after.day,before.day);assert.equal(after.phase,before.phase);assert.deepEqual(after.quests,before.quests);assert.deepEqual(after.personalQuests,before.personalQuests);assert.equal(after.player.gold,before.player.gold);
      }
    }}
  });
  await test('affinity 19/20/39/40 locks and unlocks correctly without a chat award',async()=>{
    for(const value of [19,20,39,40]){
      await seed(s=>{s.relationships.mira.value=value;s.relationships.mira.chatDay=s.day;});await page.evaluate(()=>AshenGame.talkNPC('mira',false));
      await page.locator('[data-dialogue-menu=topics]').click();assert.equal(await page.locator('[data-dialogue-start=past]').isDisabled(),value<20);assert.equal(await page.locator('[data-dialogue-start=deep]').isDisabled(),value<40);
      assert.equal(await page.evaluate(()=>DialogueSystem.start('mira','past')),value>=20);
      await page.evaluate(()=>AshenGame.talkNPC('mira',false));assert.equal(await page.evaluate(()=>DialogueSystem.start('mira','deep')),value>=40);
    }
  });
  await test('daily chat, first-choice lock, stale clicks, reload and shared room identity cannot duplicate rewards',async()=>{
    await seed(s=>{s.relationships.mira.value=20;s.relationships.mira.chatDay=0;});
    await page.evaluate(()=>{AshenGame.talkNPC('mira');AshenGame.talkNPC('mira');});assert.equal((await state()).relationships.mira.value,24);
    await advanceToChoice('mira','past');const token=await page.locator('[data-dialogue-choice]').first().getAttribute('data-dialogue-token');
    const result=await page.evaluate(token=>[DialogueSystem.choose(0,Number(token)),DialogueSystem.choose(0,Number(token)),DialogueSystem.choose(1,Number(token))],token);assert.deepEqual(result,[true,false,false]);assert.equal((await state()).relationships.mira.value,26);
    await page.keyboard.press('Escape');await page.evaluate(()=>AshenGame.talkNPC('mira'));assert.equal(await page.evaluate(()=>DialogueSystem.reading()),false);
    await advanceToChoice('mira','past');assert.equal(await page.locator('[data-dialogue-choice]').count(),0);assert.equal(await page.evaluate(()=>DialogueSystem.inspect().turn),2);
    await page.evaluate(()=>{DialogueSystem.next();DialogueSystem.next();DialogueSystem.next();AshenGame.enterBuilding('clocktower');AshenGame.talkNPC('mira');});assert.equal((await state()).relationships.mira.value,26);
    await page.reload();await page.waitForFunction(()=>window.AshenGame);assert.equal((await state()).flags['dialogue:mira:past:choice'],0);assert.equal((await state()).relationships.mira.value,26);assert.equal(await page.locator('.dialogue-reader').count(),0);
  });
  await test('partial reads, invalid input, remote NPC and combat reject actions without mutation',async()=>{
    await seed(s=>s.relationships.mira.value=40);await advanceToChoice('mira','daily');await page.keyboard.press('Escape');assert.equal((await state()).flags['dialogue:mira:daily:seen'],undefined);
    const before=await state();assert.equal(await page.evaluate(()=>DialogueSystem.start('missing','past')),false);assert.equal(await page.evaluate(()=>DialogueSystem.start('toren','daily')),false);assert.deepEqual(await state(),before);
    await advanceToChoice('mira','past');assert.equal(await page.evaluate(()=>DialogueSystem.choose(7)),false);assert.equal((await state()).flags['dialogue:mira:past:choice'],undefined);
    await page.evaluate(()=>AshenGame.travel('wood'));assert.equal(await page.evaluate(()=>DialogueSystem.choose(0)),false);assert.equal(await page.locator('.dialogue-reader').count(),0);
    await seed(s=>{s.relationships.mira.value=40;s.battle={name:'测试守卫',hp:100,maxHp:100,power:5,gold:[1,2],xp:1,round:0};});const battle=await state();assert.equal(await page.evaluate(()=>DialogueSystem.start('mira','past')),false);await page.evaluate(()=>{AshenGame.talkNPC('mira');AshenGame.giftNPC('mira');});assert.deepEqual(await state(),battle);
  });
  await test('old v2-v6 saves initialize empty records and malformed flags are isolated',async()=>{
    for(const schema of [2,3,4,5,6]){
      await seed(s=>{s.schema=schema;s.flags={'dialogue:mira:past:choice':'0','dialogue:toren:past:choice':0,'dialogue:mira:daily:choice':0,'dialogue:mira:past:seen':'yes','dialogue:missing:past:choice':0,'dialogue:mira:unknown:seen':true,'dialogue:mira:daily:seen':true,'ordinary-flag':17};});
      const s=await state();assert.equal(s.schema,6);assert.equal(s.flags['dialogue:toren:past:choice'],0);assert.equal(s.flags['dialogue:mira:daily:seen'],true);assert.equal(s.flags['ordinary-flag'],17);assert.equal(Object.keys(s.flags).filter(k=>k.startsWith('dialogue:')).length,2);
    }
    await seed(()=>{});assert.equal(Object.keys((await state()).flags).filter(k=>k.startsWith('dialogue:')).length,0);
  });
  await test('export and import retain branch records without saving the current sentence',async()=>{
    await seed(s=>{s.relationships.mira.value=40;s.flags['dialogue:mira:past:choice']=1;s.flags['dialogue:mira:past:seen']=true;});await advanceToChoice('mira','past');
    const downloadPromise=page.waitForEvent('download');await page.evaluate(()=>AshenGame.command('save'));await page.evaluate(()=>AshenGame.showScreen('settings'));await page.locator('[data-action=export]').click();const download=await downloadPromise;
    const saved=JSON.parse(fs.readFileSync(await download.path(),'utf8'));assert.equal(saved.flags['dialogue:mira:past:choice'],1);assert.equal(saved.flags['dialogue:mira:past:seen'],true);assert(!saved.dialogueSession);
    await seed(()=>{});await page.evaluate(()=>AshenGame.showScreen('settings'));await page.locator('#importFile').setInputFiles({name:'dialogue-save.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(saved))});
    await page.waitForFunction(()=>AshenGame.getState().flags['dialogue:mira:past:choice']===1);assert.equal(await page.locator('.dialogue-reader').count(),0);
  });
  await test('main and personal quest greetings change and all four time greetings are distinct',async()=>{
    const result=await page.evaluate(()=>{
      const s=AshenGame.getState(),main=[];for(let stage=0;stage<=8;stage++){s.storyStage=stage;main.push(DialogueContent.greeting(s,'mira'));}
      const quests=[];delete s.quests.herbs;quests.push(DialogueContent.greeting(s,'pella'));s.quests.herbs={progress:1,done:false};quests.push(DialogueContent.greeting(s,'pella'));s.quests.herbs.done=true;quests.push(DialogueContent.greeting(s,'pella'));
      const personal=[];delete s.personalQuests.alchemist;personal.push(DialogueContent.greeting(s,'alchemist'));s.personalQuests.alchemist={stage:0,done:false};personal.push(DialogueContent.greeting(s,'alchemist'));s.personalQuests.alchemist.done=true;personal.push(DialogueContent.greeting(s,'alchemist'));
      const phases=[];for(let phase=0;phase<4;phase++){s.phase=phase;phases.push(DialogueContent.greeting(s,'pella'));}return {main,quests,personal,phases};
    });assert.equal(new Set(result.main).size,9);assert.equal(new Set(result.quests).size,3);assert.equal(new Set(result.personal).size,3);assert.equal(new Set(result.phases).size,4);
  });
  await test('repeat old quests do not spam logs; existing Toren/Eira quests still advance story',async()=>{
    await seed(()=>{});await meet('pella');await page.evaluate(()=>AshenGame.chooseNPC('pella','accept'));const after=await state();await page.evaluate(()=>AshenGame.chooseNPC('pella','accept'));assert.equal((await state()).log.length,after.log.length);
    for(const [id,quest,stage,next,place] of [['toren','caravan',3,4,'pass'],['eira','names',5,6,'fen']]){
      await seed(s=>{s.place=place;s.storyStage=stage;s.quests[quest]={progress:1,done:false};});await page.evaluate(id=>AshenGame.chooseNPC(id,'accept'),id);assert.equal((await state()).storyStage,next);
    }
    await seed(s=>{s.storyStage=8;s.regionQuests.epilogue={stage:1,done:false};s.place='wood';});await page.evaluate(()=>AshenGame.talkNPC('mira',false));assert.equal(await page.locator('[data-epilogue]').count(),0);
    await page.evaluate(()=>{const b=document.createElement('button');b.dataset.epilogue='1';document.body.append(b);b.click();b.remove();});assert.equal((await state()).regionQuests.epilogue.done,false);
  });
  await test('gift cost and regional service availability show actual stock, daily limits and discounts',async()=>{
    await seed(s=>{s.inventory.materials.shard=0;});await page.evaluate(()=>AshenGame.talkNPC('mira',false));await page.locator('[data-dialogue-menu=gift]').click();assert(await page.locator('[data-dialogue-gift=mira]').isDisabled());assert((await page.locator('[data-dialogue-gift=mira]').textContent()).includes('星屑 ×1'));
    await seed(s=>{s.player.gold=100;s.relationships['stable-hand'].value=60;});await page.evaluate(()=>AshenGame.talkNPC('stable-hand',false));await page.locator('[data-dialogue-menu=service]').click();assert((await page.locator('[data-indoor-service]').textContent()).includes('金币 7'));
    await seed(s=>{s.flags['world-service:drill:town']=s.day;});await page.evaluate(()=>AshenGame.talkNPC('gate-knight',false));await page.locator('[data-dialogue-menu=service]').click();assert(await page.locator('[data-indoor-service]').isDisabled());assert((await page.locator('[data-indoor-service]').textContent()).includes('今日已使用'));
  });
  await test('dialogue segments, Escape hierarchy, focus trap and configured client frame layouts',async()=>{
    await seed(s=>{s.relationships.mira.value=40;s.settings.reduceMotion=true;});
    await page.evaluate(()=>AshenGame.talkNPC('mira',false));await page.locator('[data-dialogue-menu=topics]').click();await page.locator('[data-dialogue-start=daily]').click();
    await page.keyboard.press('Escape');assert.equal(await page.evaluate(()=>DialogueSystem.inspect().layer),'topics');await page.keyboard.press('Escape');assert.equal(await page.evaluate(()=>DialogueSystem.inspect().layer),'hub');await page.keyboard.press('Escape');assert.equal(await page.locator('#modal.open').count(),0);
    for(const viewport of require('./client-fixture.cjs').viewports.map(([width,height])=>({width,height}))){
      await page.setViewportSize(viewport);await page.waitForTimeout(180);await page.evaluate(()=>AshenGame.talkNPC('mira',false));await advanceToChoice('mira','daily');
      const layout=await page.evaluate(()=>({width:document.documentElement.scrollWidth,frame:GameViewport.size(),buttons:[...document.querySelectorAll('.dialogue-reader button:not([hidden])')].map(b=>GameViewport.localRect(b))}));
      assert(layout.width<=viewport.width);for(const r of layout.buttons){assert(r.height>=43.9);assert(r.y>=-1&&r.y+r.height<=layout.frame.height+1,JSON.stringify({viewport,r}));}
      await page.waitForFunction(()=>!document.querySelector('#toast.show'));await page.screenshot({path:'artifacts/dialogue-'+viewport.width+'x'+viewport.height+'.png'});
      await page.evaluate(()=>{DialogueContent.people.mira.daily.intro[0]='这是一段用于检查分段的长对白。'.repeat(90);DialogueSystem.start('mira','daily');});
      const result=await page.evaluate(()=>({segments:DialogueSystem.inspect().segments,overflow:document.querySelector('.dialogue-text').scrollHeight>document.querySelector('.dialogue-text').clientHeight+1}));assert(result.segments>1);assert(!result.overflow);
    }
  });
  assert.deepEqual(errors,[]);console.log('PASS no runtime or resource errors');
  fs.writeFileSync('artifacts/dialogue-acceptance.json',JSON.stringify({url,passed,errors},null,2));await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});
