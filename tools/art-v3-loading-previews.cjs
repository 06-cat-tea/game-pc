const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/');
(async()=>{fs.mkdirSync('artifacts/art-v3',{recursive:true});const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
 for(const place of ['town','wood','pass','fen','coast','city']){
  const p=await browser.newPage({viewport:{width:1920,height:1080}});let release;const held=new Promise(r=>release=r);
  await p.route('**/portraits/hero-256.png*',async r=>{await held;await r.continue();});
  try{await p.goto(url);await p.waitForFunction(()=>!GameLoading.blocked());await p.evaluate(place=>{const s=AshenGame.getState();s.place=place;s.location={sceneId:null,...WorldRegions.spawn(place),zoom:1,stack:[]};localStorage.setItem('ashen-frontier-save-v3',JSON.stringify(s));AshenGame.command('load');},place);
   await p.waitForFunction(place=>WorldAssets.inspect('loading',place)?.status==='ready'&&getComputedStyle(document.querySelector('#gameLoading')).backgroundImage.includes('/loading/'+place+'.webp'),place);await p.screenshot({path:'artifacts/art-v3/loading-'+place+'.png'});
   release();await p.waitForFunction(()=>!GameLoading.blocked());console.log('CAPTURE '+place);
  }finally{release();await p.close();}
 }
 await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
