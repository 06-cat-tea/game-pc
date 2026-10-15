const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const {id,saveKey}=require('../client.json');
const source=fs.readFileSync('js/client-platform.js','utf8');
function fixture(entries={},failWrites=false){
  const values=new Map(Object.entries(entries)),warnings=[];
  const w={URL,location:{href:'https://example.test/frontier.html'},document:{addEventListener(){}},
    console:{warn:s=>warnings.push(s)},localStorage:{getItem:k=>values.has(k)?values.get(k):null,
      setItem(k,v){if(failWrites)throw Error('quota');values.set(k,String(v));}}};
  w.window=w;vm.runInNewContext(source,w);return {api:w.GameClient,values,warnings};
}
const oldKey='ashen-frontier-save-v3',old=JSON.stringify({schema:4,player:{level:8},inventory:{owned:['sword']}});
{
  const {api,values}=fixture({[oldKey]:old});api.prepareLegacySave();
  assert.equal(api.id,id);assert.equal(api.readSave().player.level,8);assert(!values.has(saveKey));
  api.finishLegacySave({schema:6,player:{level:8}});
  assert.equal(JSON.parse(values.get(saveKey)).schema,6);assert.equal(values.get(oldKey),old);
  values.set(saveKey,JSON.stringify({schema:6,player:{level:12}}));
  api.prepareLegacySave();assert.equal(api.readSave().player.level,12);
}
{
  const current=JSON.stringify({schema:6,player:{level:2}}),{api,values}=fixture({[saveKey]:current,[oldKey]:old});
  api.prepareLegacySave();api.finishLegacySave({schema:6,player:{level:99}});assert.equal(values.get(saveKey),current);
}
{
  const {api}=fixture({[oldKey]:'{damaged','ashen-frontier-save-v2':JSON.stringify({schema:2,level:7})});
  api.prepareLegacySave();assert.equal(api.readSave().level,7);
}
{
  const {api,values,warnings}=fixture({[oldKey]:old},true);api.prepareLegacySave();
  api.finishLegacySave({schema:6});assert(!values.has(saveKey));assert.equal(values.get(oldKey),old);assert.equal(warnings.length,1);
}
{
  const other='ashen-frontier-save-v3-'+(id==='desktop'?'mobile':'desktop');
  const {api}=fixture({[other]:old});api.prepareLegacySave();assert.equal(api.readSave(),null);
}
{
  const {api}=fixture({'ashen-frontier-save-v2':JSON.stringify({level:9})});
  api.prepareLegacySave();assert.equal(api.readSave().schema,2);assert.equal(api.readSave().level,9);
}
console.log('PASS client save namespace, legacy inheritance, existing slot priority, damaged legacy fallback and quota protection');
