#!/usr/bin/env node
// Render the existing Swedish branding and genuine phone captures for Play.
// Set NODE_PATH to the directory containing sharp when it is not installed locally.
const fs=require('node:fs/promises'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'Android/release-preparation');
(async()=>{
 const graphics=path.join(out,'graphics'),screens=path.join(out,'store-listing/en-US/phone-screenshots');
 await fs.mkdir(graphics,{recursive:true});await fs.mkdir(screens,{recursive:true});
 await sharp(path.join(root,'Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png')).resize(512,512).ensureAlpha().png().toFile(path.join(graphics,'app-icon-512.png'));
 const report={};
 for(const name of ['01-study-prompt.png','02-study-answer.png','03-progress.png','04-offline-options.png']) {
  const source=path.join(root,'Verification/Android/screenshots',name),meta=await sharp(source).metadata();
  if(meta.width!==1080 || meta.height!==2340)throw Error('Capture dimensions changed; re-check padding.');
  // Keep every screenshot pixel at its original size; 45px side margins give a 1:2 canvas.
  const target=path.join(screens,name);
  await sharp(source).removeAlpha().extend({left:45,right:45,top:0,bottom:0,background:'#F5F8FC'}).png().toFile(target);
  report[name]={width:1170,height:2340,sourceWidth:1080,sourceHeight:2340,sidePadding:45,scaled:false};
 }
 const manifest=JSON.parse(await fs.readFile(path.join(root,'Resources/BundledArtwork/manifest.json'),'utf8'));
 const artwork=manifest.find(r=>r.wordID==='sv-0136').filename;
 const data=(await fs.readFile(path.join(root,'Resources/BundledArtwork',artwork))).toString('base64');
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500"><rect width="1024" height="500" fill="#006AA7"/><g font-family="Arial, sans-serif" fill="#FAF9F5"><text x="70" y="108" font-size="27" font-weight="600">3000 Swedish Words</text><rect x="70" y="147" width="64" height="5" rx="2.5" fill="#FECC00"/><text x="70" y="224" font-size="43" font-weight="700">Remember Swedish.</text><text x="70" y="282" font-size="40" font-weight="700">One picture at a time.</text><text x="72" y="350" font-size="21">Illustrated lessons · Recorded pronunciation</text><text x="72" y="399" font-size="22" fill="#FECC00">English ↔ Swedish</text></g><rect x="670" y="45" width="284" height="410" rx="22" fill="#FAF9F5"/><image x="682" y="57" width="260" height="386" preserveAspectRatio="xMidYMid meet" href="data:image/jpeg;base64,${data}"/></svg>`;
 await fs.writeFile(path.join(graphics,'feature-graphic.svg'),svg);
 await sharp(Buffer.from(svg)).removeAlpha().png().toFile(path.join(graphics,'feature-graphic-1024x500.png'));
 await fs.writeFile(path.join(out,'graphics-validation.json'),JSON.stringify({screenshots:report,icon:{width:512,height:512},featureGraphic:{width:1024,height:500,sourceArtwork:'sv-0136',newAIImageGenerated:false}},null,2)+'\n');
 console.log('Prepared icon, feature graphic, and four screenshots; original UI pixels preserved.');
})().catch(e=>{console.error(e.message);process.exitCode=1});
