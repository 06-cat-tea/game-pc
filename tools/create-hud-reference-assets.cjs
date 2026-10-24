// Editable, scalable HUD pictograms and a cartographic minimap derived from live town geometry.
const fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'..');
const out=path.join(root,'godot/assets/ui/hud-filled');fs.mkdirSync(out,{recursive:true});
const cream='#f4ead1',ink='#303b37',gold='#dbc48e';
const shapes={
 skills:'<path d="M32 2 39 23 61 30 40 38 32 62 24 40 3 32 23 24z"/><path d="m47 5 4 9 9 4-9 4-4 9-4-9-9-4 9-4z"/>',
 craft:'<path d="M13 5h29l14 14-9 9-12-9-6 6 25 28-10 9L19 33l-8 8-8-8 17-17z"/><path d="m48 3 13 13-8 8-13-13z"/>',
 map:'<path d="m3 13 18-9 22 9 18-9v47l-18 9-22-9-18 9z"/><path d="M21 9v36m22-26v35" stroke="#303b37" stroke-width="3"/>',
 rest:'<path d="M46 3c-20 3-26 28-9 39 7 5 14 5 22 1-6 17-28 24-43 10C-2 36 8 7 30 4c-14 13-9 32 4 36C21 25 28 9 46 3z"/>',
 settings:'<path d="m25 2 14 0 3 10 9 5 10-2 5 13-8 7-1 10 5 9-11 9-9-5-10 1-7 8-12-6 2-10-5-9-10-3V25l10-3 5-9-2-9 12-5z" transform="translate(3 3) scale(.87)"/><circle cx="32" cy="32" r="11" fill="#303b37"/>',
 quest:`<path d="M11 9h36v42H13V18H8V9h7v34h32v8H13q-7 0-7-7v-4h7"/><path d="M43 9h9v36h-9"/><path fill="${ink}" d="M27 19h7l-1 16h-5z"/><circle fill="${ink}" cx="30.5" cy="41" r="2.5"/>`,
 backpack:`<path d="M22 20V14q0-13 20-13v6q-14-1-14 8v5zm-11 5q0-8 8-8h28q8 0 8 8v27q0 7-8 7H19q-8 0-8-7z"/><path fill="${ink}" d="M17 21h33v12H17z"/><path d="M18 22h31v8H18z"/><rect x="24" y="35" width="20" height="17" rx="3" fill="${ink}"/><rect x="27" y="37" width="14" height="12" rx="2"/><path fill="${ink}" d="M31 24h5v10h-5z"/>`,
 character:`<path d="M32 2 42 22 62 32 42 42 32 62 22 42 2 32 22 22z"/><path fill="${ink}" d="M32 11 34 28 50 32 34 36 32 53 30 36 14 32 30 28z"/>`,
 party:`<circle cx="26" cy="18" r="11"/><circle cx="48" cy="23" r="8"/><path d="M6 54V44q0-16 20-16t20 16v10zM45 36q14-2 16 12v6H49V44q0-4-4-8"/>`,
 terminal:`<circle cx="32" cy="32" r="26" fill="none" stroke="${cream}" stroke-width="2"/><path d="M32 0 36 26 59 32 36 36 32 64 28 36 5 32 28 26z"/><path fill="${ink}" d="M32 23 36 32 32 41 28 32z"/>`,
 sun:`<circle cx="32" cy="32" r="12"/><g stroke="${gold}" stroke-width="4" stroke-linecap="round"><path d="M32 3v8m0 42v8M3 32h8m42 0h8M11 11l6 6m30 30 6 6M11 53l6-6m30-30 6-6"/></g>`,
 diamond:`<path d="M32 2 60 32 32 62 4 32z" fill="${gold}" stroke="${cream}" stroke-width="2"/><path fill="${ink}" d="M28 16h8l-1 23h-6z"/><circle cx="32" cy="46" r="3" fill="${ink}"/>`,
 star:`<path d="M32 0 38 25 64 32 38 38 32 64 26 38 0 32 26 25z" fill="${gold}"/><path d="M32 10 36 28 54 32 36 36 32 54 28 36 10 32 28 28z" fill="${cream}"/>`,
 clock:`<path d="M25 8h15l8 12H17zM21 21h23v38H21z"/><circle cx="32" cy="31" r="8" fill="${ink}"/><path d="M32 25v6l5 3" fill="none" stroke="${cream}" stroke-width="2"/><path d="M28 48h8v11h-8z" fill="${ink}"/>`,
 chapel:`<path d="M10 32 32 13 54 32v27H10zM28 1h8v22h-8zM22 7h20v7H22z"/><path d="M26 59V45q6-11 12 0v14z" fill="${ink}"/>`,
 inn:`<path d="M3 29 32 5 61 29H3M10 30h44v29H10z"/><path d="M19 36h7v8h-7zm20 0h7v8h-7zM29 44h8v15h-8z" fill="${ink}"/>`,
 market:`<path d="M7 10h50l5 17H2zM5 28h54v8q-6 7-12 0-7 7-15 0-8 7-15 0-6 7-12 0zM10 37h6v16h32V37h6v22H10z"/>`
};
for(const [name,body]of Object.entries(shapes))fs.writeFileSync(path.join(out,name+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64" fill="${name==='sun'?gold:cream}">${body}</svg>`);
console.log('Created filled HUD and wheel pictograms.');
