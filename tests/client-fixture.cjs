const client=require('../client.json');
module.exports={...client,viewports:client.mobile?
  [[844,390,true],[640,360,true],[390,844,true],[360,640,true]]:
  [[1920,1080,false],[1280,720,false]]};
