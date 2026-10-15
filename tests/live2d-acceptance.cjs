// Uses an isolated browser profile; never changes the user's game save.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const url = process.argv[2] || 'file:///' + path.resolve('frontier.html').replaceAll('\\', '/');
(async () => {
  fs.mkdirSync('artifacts', {recursive:true});
  const browser = await chromium.launch({executablePath:process.env.CHROME_PATH, headless:true});
  const page = await browser.newPage({viewport:{width:1280,height:720}}), errors=[], expectedErrors=[], warnings=[], passed=[];
  let corruptFixture=false;
  function recordError(message) {(corruptFixture && /moc/i.test(message) ? expectedErrors : errors).push(message);}
  page.on('pageerror', e => recordError(e.message));
  page.on('console', m => {if(m.type()==='error') recordError(m.text()); if(m.type()==='warning') warnings.push(m.text());});
  async function meet(reduceMotion=false) {
    await page.evaluate(reduceMotion => {
      const s = AshenGame.getState(); s.place='town';s.battle=null;s.relationships.mira.value=80;s.settings.reduceMotion=reduceMotion;
      s.location={sceneId:null,x:10,y:12,zoom:1,stack:[]};
      localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');AshenGame.talkNPC('mira',false);
    }, reduceMotion);
  }
  async function ready() {await page.waitForFunction(()=>Live2DPortraits.inspect().active && document.querySelector('.character-standing-art')?.hidden);}
  async function test(name, run) {await run();passed.push(name);console.log('PASS '+name);}
  await page.goto(url);await page.waitForFunction(()=>window.AshenGame);assert.equal(await page.evaluate(()=>typeof window.AshenCubism),'undefined','SDK must remain unloaded until a model is needed');await page.locator('[data-command=continue]').click();
  await test('genuine Mira MOC3 loads through the bundled official SDK under file://', async()=>{
    await meet();await ready();
    const first=await page.evaluate(()=>Live2DPortraits.inspect());
    assert.equal(first.id,'mira');assert(first.parameters.includes('ParamBreath'));assert(first.parameters.includes('ParamHairBack'));
    const pixels=await page.locator('.character-live2d').screenshot();
    await page.waitForTimeout(400);const next=await page.evaluate(()=>Live2DPortraits.inspect());assert.notEqual(first.values.ParamBreath,next.values.ParamBreath);
    assert.notDeepEqual(pixels,await page.locator('.character-live2d').screenshot(),'The rendered model must move, not only its parameter values');
    await page.screenshot({path:'artifacts/live2d-mira-runtime.png'});
  });
  await test('expression mouth combinations and motion extrema remain valid in the exported MOC3',async()=>{
    const report=await page.evaluate(()=>{
      const bytes=Uint8Array.from(atob(CharacterModelBundles.mira.moc),c=>c.charCodeAt(0));
      const user=new AshenCubism.CubismUserModel();user.loadModel(bytes.buffer,true);const model=user.getModel();
      const params=new Map(Array.from({length:model.getParameterCount()},(_,i)=>[model.getParameterId(i).getString(),i]));
      const ids=Array.from({length:model.getDrawableCount()},(_,i)=>model.getDrawableId(i).getString());
      function set(name,value){model.setParameterValueByIndex(params.get(name),value);}
      const mouths=[];let finite=true,trianglesValid=true,samples=0;
      for(const form of [-1,0,1])for(const open of [0,1]){
        set('ParamMouthForm',form);set('ParamMouthOpenY',open);model.update();
        mouths.push({form,open,opacities:Object.fromEntries(ids.map((id,i)=>[id,model.getDrawableOpacity(i)]))});
      }
      // Compare signed triangle areas with the neutral mesh: no inverted triangles.
      model.loadParameters();model.update();
      const areas=ids.map((id,i)=>{const v=model.getDrawableVertexPositions(i),ix=model.getDrawableVertexIndices(i),a=[];
        for(let j=0;j<ix.length;j+=3){const [p,q,r]=[ix[j]*2,ix[j+1]*2,ix[j+2]*2];a.push((v[q]-v[p])*(v[r+1]-v[p+1])-(v[q+1]-v[p+1])*(v[r]-v[p]));}return a;});
      for(const x of [-30,0,30])for(const y of [-30,0,30])for(const hair of [-1,0,1])for(const body of [-10,0,10])for(const breath of [0,1]){
        set('ParamAngleX',x);set('ParamAngleY',y);set('ParamHairFront',hair);set('ParamHairBack',-hair);
        set('ParamBodyAngleY',body);set('ParamBodyAngleZ',body);set('ParamBreath',breath);model.update();samples++;
        ids.forEach((id,i)=>{const v=model.getDrawableVertexPositions(i),ix=model.getDrawableVertexIndices(i);finite&&=Array.from(v).every(Number.isFinite);
          for(let j=0;j<ix.length;j+=3){const [p,q,r]=[ix[j]*2,ix[j+1]*2,ix[j+2]*2],a=(v[q]-v[p])*(v[r+1]-v[p+1])-(v[q+1]-v[p+1])*(v[r]-v[p]);
            if(Math.abs(areas[i][j/3])>1e-8)trianglesValid&&=a*areas[i][j/3]>0;}});
      }
      const result={meshes:ids.length,parameters:params.size,parts:model.getPartCount(),mouths,samples,finite,trianglesValid};user.release();return result;
    });
    fs.writeFileSync('artifacts/live2d-mira-model-check.json',JSON.stringify(report,null,2));
    assert(report.meshes<=100&&report.parameters<=30&&report.parts<=30);assert(report.finite);assert(report.trianglesValid);
    for(const m of report.mouths){
      assert.equal(m.opacities.ArtMesh3,m.form===-1&&m.open===0?1:0,'serious mouth');
      assert.equal(m.opacities.ArtMesh4,m.form===1&&m.open===0?1:0,'smiling mouth');
      assert.equal(m.opacities.ArtMesh5,m.form===0&&m.open===0?1:0,'neutral mouth');
    }
    for(const expression of ['neutral','smile','serious']){
      await page.evaluate(expression=>{DialogueSystem.advance();Live2DPortraits.setExpression(expression);},expression);
      await page.waitForTimeout(140);assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().values.ParamMouthForm),expression==='smile'?1:expression==='serious'?-1:0);
    }
  });
  await test('speaker switches to the player reply and returns to Mira',async()=>{
    await page.evaluate(()=>{DialogueSystem.start('mira','daily');DialogueSystem.next();DialogueSystem.next();});
    assert.equal(await page.locator('.dialogue-character').getAttribute('data-character-id'),'mira');
    await page.evaluate(()=>DialogueSystem.choose(0));
    assert.equal(await page.locator('.dialogue-speaker').textContent(),'你');assert.equal(await page.locator('.dialogue-character').getAttribute('data-character-id'),'hero');
    assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);
    await page.evaluate(()=>DialogueSystem.next());await ready();assert.equal(await page.locator('.dialogue-character').getAttribute('data-character-id'),'mira');
  });
  await test('speech pulses stop at punctuation, completion and fast skip',async()=>{
    await page.evaluate(()=>{Live2DPortraits.pulse('说');});assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().mouthOpen),true);
    await page.evaluate(()=>Live2DPortraits.pulse('。'));assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().mouthOpen),false);
    await page.evaluate(()=>DialogueSystem.advance());await page.waitForTimeout(120);assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().mouthOpen),false);
    await page.evaluate(()=>{Live2DPortraits.pulse('话');Live2DPortraits.pause(true);});assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);
    await page.evaluate(()=>Live2DPortraits.pause(false));await ready();
  });
  await test('repeated dialogue opens and reset dispose the previous model',async()=>{
    for(let i=0;i<6;i++){await meet();await ready();await page.evaluate(()=>DialogueSystem.reset());assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);}
  });
  await test('cancel during loading, service changes, visibility and lost WebGL contexts cleanly stop the model',async()=>{
    await meet();await ready();
    await page.evaluate(()=>{Live2DPortraits.mount(document.querySelector('.dialogue-character'),'mira');DialogueSystem.reset();});
    await page.waitForTimeout(160);assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);
    await meet();await ready();
    await page.evaluate(()=>AshenGame.talkNPC('stable-hand',false));await page.locator('[data-dialogue-menu=service]').click();
    assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);
    await page.locator('[data-dialogue-back]').click();await meet();await ready();
    await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'));});
    const paused=await page.evaluate(()=>Live2DPortraits.inspect());assert(paused.paused);assert(!paused.active);
    await page.waitForTimeout(140);assert.deepEqual((await page.evaluate(()=>Live2DPortraits.inspect())).values,paused.values);
    await page.evaluate(()=>{delete document.hidden;document.dispatchEvent(new Event('visibilitychange'));});await ready();
    await page.evaluate(()=>Live2DPortraits.setExpression('serious'));
    await page.waitForFunction(()=>document.querySelector('.character-standing-art')?.dataset.loadedExpression==='serious');
    await page.evaluate(()=>document.querySelector('.character-live2d').getContext('webgl').getExtension('WEBGL_lose_context').loseContext());
    await page.waitForTimeout(150);assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);assert(await page.locator('.character-standing-art').isVisible());
    assert.equal(await page.locator('.character-standing-art').getAttribute('data-loaded-expression'),'serious');
  });
  await test('automatic reading pauses at choices and keeps the resident until the player replies',async()=>{
    await meet();await page.evaluate(()=>{DialogueSystem.start('mira','daily');DialogueSystem.advance();});await ready();
    await page.locator('[data-dialogue-auto]').click();await page.waitForFunction(()=>DialogueSystem.inspect().turn===1);
    await page.evaluate(()=>DialogueSystem.advance());await page.waitForFunction(()=>DialogueSystem.inspect().turn===2);
    await page.waitForTimeout(900);assert.equal(await page.evaluate(()=>DialogueSystem.inspect().turn),2);
    assert.equal(await page.locator('.dialogue-character').getAttribute('data-character-id'),'mira');
    await page.evaluate(()=>DialogueSystem.advance());await page.waitForTimeout(140);assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().mouthOpen),false);
    await page.locator('[data-dialogue-auto]').click();
  });
  await test('animated portrait fits configured client sizes including rotated touch coordinates',async()=>{
    for(const viewport of require('./client-fixture.cjs').viewports.map(([width,height])=>({width,height}))){
      const layoutPage=await browser.newPage({viewport,hasTouch:viewport.width<900,isMobile:viewport.width<900});
      layoutPage.on('pageerror',e=>recordError(e.message));layoutPage.on('console',m=>{if(m.type()==='error')recordError(m.text());});
      await layoutPage.goto(url);await layoutPage.waitForFunction(()=>window.AshenGame);await layoutPage.locator('[data-command=continue]').click();
      await layoutPage.evaluate(()=>{const s=AshenGame.getState();s.place='town';s.battle=null;s.relationships.mira.value=80;s.settings.reduceMotion=false;
        s.location={sceneId:null,x:10,y:12,zoom:1,stack:[]};localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');AshenGame.talkNPC('mira',false);});
      await layoutPage.waitForFunction(()=>Live2DPortraits.inspect().active&&document.querySelector('.character-standing-art')?.hidden);await layoutPage.waitForTimeout(180);
      const layout=await layoutPage.evaluate(()=>{const canvas=document.querySelector('.character-live2d'),r=GameViewport.localRect(canvas);return {r,frame:GameViewport.size(),width:canvas.width,height:canvas.height,scroll:document.documentElement.scrollWidth};});
      assert(layout.r.x>=0&&layout.r.y>=0&&layout.r.x+layout.r.width<=layout.frame.width+1&&layout.r.y+layout.r.height<=layout.frame.height+1);
      assert.equal(layout.width,Math.round(layout.r.width));assert.equal(layout.height,Math.round(layout.r.height));assert(layout.scroll<=viewport.width);
      assert.equal(layout.frame.rotated,require('./client-fixture.cjs').mobile&&viewport.width<viewport.height);
      await layoutPage.screenshot({path:'artifacts/live2d-'+viewport.width+'x'+viewport.height+'.png'});await layoutPage.close();
    }
  });
  await test('reduced motion keeps the static standing portrait',async()=>{
    await meet(true);assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);
    assert.equal(await page.locator('.character-standing-art').isVisible(),true);assert.equal(await page.locator('.character-live2d').isVisible(),false);
  });
  await test('invalid MOC3 falls back to the static portrait and cleans up',async()=>{
    await meet(true);
    corruptFixture=true;
    await page.evaluate(()=>{const bundle=CharacterModelBundles.mira;window.testOriginalMoc=bundle.moc;bundle.moc=btoa('invalid');Live2DPortraits.mount(document.querySelector('.dialogue-character'),'mira',false);});
    await page.waitForTimeout(350);assert.equal(await page.evaluate(()=>Live2DPortraits.inspect().active),false);assert(await page.locator('.character-standing-art').isVisible());
    await page.evaluate(()=>{CharacterModelBundles.mira.moc=testOriginalMoc;delete window.testOriginalMoc;});
    corruptFixture=false;
  });
  fs.writeFileSync('artifacts/live2d-acceptance.json',JSON.stringify({url,passed,errors,expectedErrors,warnings},null,2));
  assert.deepEqual(errors,[]);await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});
