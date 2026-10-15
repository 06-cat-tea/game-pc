// Preserve the original dependency order while serving one minified local script.
const fs=require('node:fs'),path=require('node:path'),esbuild=require('esbuild');
const root=path.resolve(__dirname,'..'),scripts=JSON.parse(fs.readFileSync(path.join(__dirname,'game-scripts.json'),'utf8'));
const source=scripts.map(file=>fs.readFileSync(path.join(root,file),'utf8')).join('\n;\n');
const result=esbuild.transformSync(source,{minify:true,target:'es2020',charset:'utf8',legalComments:'eof'});
fs.writeFileSync(path.join(root,'js/game-bundle.js'),result.code);
console.log(JSON.stringify({scripts:scripts.length,sourceBytes:Buffer.byteLength(source),bundleBytes:Buffer.byteLength(result.code)}));
