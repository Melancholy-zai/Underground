// Real SVG + JavaScript integration regression, using the app's offline assets.
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
(async()=>{
 const root=path.resolve(__dirname,'../..');
 const pack=JSON.parse(fs.readFileSync(path.join(root,'App/Resources/CityPack/city.json'),'utf8'));
 const svg=fs.readFileSync(path.join(root,'App/Resources/CityPack/map.svg'),'utf8');
 const script=fs.readFileSync(path.join(root,'App/Resources/Web/map.js'),'utf8');
 const html=fs.readFileSync(path.join(root,'App/Resources/Web/map.html'),'utf8').replace('<!--METRO_SVG-->',svg).replace('/*METRO_SCRIPT*/',script);
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 try {
  const page=await browser.newPage({viewport:{width:1100,height:700}});
  await page.setContent(html);await page.evaluate(()=>document.fonts.ready);
  for(const selected of pack.lines){
   const expected=new Set([selected.id]);
   for(let changed=true;changed;){changed=false;for(const service of pack.throughServices||[]){if(service.lineIDs.some(id=>expected.has(id)))for(const id of service.lineIDs){if(!expected.has(id)){expected.add(id);changed=true;}}}}
   const result=await page.evaluate(id=>{
    window.metro.update({line:id});
    return {lines:[...document.querySelectorAll('[data-line]')].filter(n=>n.style.opacity==='1').map(n=>n.dataset.line).sort(),stations:[...document.querySelectorAll('[data-station]')].filter(n=>n.style.opacity==='1').map(n=>n.dataset.station).sort()};
   },selected.id);
   assert.deepEqual(result.lines,[...expected].sort(),selected.name+' highlighted lines');
   assert.deepEqual(result.stations,pack.stations.filter(s=>s.lineIDs.some(id=>expected.has(id))).map(s=>s.id).sort(),selected.name+' highlighted stations');
  }
  const geometry=await page.evaluate(()=>{
   const lines=[...document.querySelectorAll('[data-line]')].map(n=>{const p=n.querySelector('path.line');return {id:n.dataset.line,moves:(p.getAttribute('d').match(/M/gi)||[]).length,length:p.getTotalLength()};});
   const a=document.querySelector('#line-l2 path.line'),b=document.querySelector('#line-l8 path.line');
   const end=a.getPointAtLength(a.getTotalLength()),start=b.getPointAtLength(0);
   return {lines,seamDistance:Math.hypot(start.x-end.x,start.y-end.y)};
  });
  for(const line of geometry.lines){assert.equal(line.moves,1,line.id+' disconnected subpaths');assert.ok(line.length>0,line.id+' empty path');}
  assert.ok(geometry.seamDistance<.1,'2/8 seam at Liantang must be continuous');
  const liantang=pack.stations.find(s=>s.name==='莲塘');
  await page.evaluate(id=>window.metro.update({line:'l8',command:{id:'line8-regression',kind:'focus',target:id}}),liantang.id);
  // Wait for two paints, including the normal opacity transition, before evidence capture.
  await page.waitForFunction(()=>getComputedStyle(document.querySelector('#line-l2')).opacity==='1');
  if(process.argv[2]){fs.mkdirSync(path.dirname(path.resolve(process.argv[2])),{recursive:true});await page.screenshot({path:process.argv[2]});}
  console.log(`PASS: ${pack.lines.length} line selections and station sets; ${geometry.lines.length} continuous SVG paths; Liantang seam ${geometry.seamDistance.toFixed(3)} units`);
 } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
