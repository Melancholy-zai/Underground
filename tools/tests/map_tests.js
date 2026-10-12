// Run with system JavaScriptCore from repository root; no npm dependencies.
let resizeCallback;
const attrs = {}, handlers = {}, events = [];
let target = null;
const station = {dataset:{station:'qianhaiwan',x:'600',y:'500',lines:'l1'},classList:{toggle(){}},style:{}};
const liantang = {dataset:{station:'liantang',x:'800',y:'500',lines:'l2'},classList:{toggle(){}},style:{}};
const wutong = {dataset:{station:'wutong',x:'900',y:'500',lines:'l8'},classList:{toggle(){}},style:{}};
const interchange = {dataset:{station:'interchange',x:'700',y:'500',lines:'l2 l5'},classList:{toggle(){}},style:{}};
const allStations = [station,liantang,wutong,interchange];
const allLines = ['l1','l2','l8','l5'].map(id=>({dataset:{line:id,highlightLines:['l2','l8'].includes(id)?'l2 l8':id},style:{}}));
const legends = ['l1','l2','l8','l5'].map(id=>({dataset:{legendLine:id},attrs:{},classList:{toggle(name,on){this[name]=on}},setAttribute(k,v){this.attrs[k]=v}}));
station.closest = key => key === '[data-station]' ? station : null;
const focusAreas = [
  {dataset:{mapFocus:'surroundings',x:'3000',y:'200',width:'900',height:'600'}},
  {dataset:{mapFocus:'legend-lines',x:'200',y:'2500',width:'600',height:'200'}},
  {dataset:{mapFocus:'oversized',x:'0',y:'0',width:'9000',height:'9000'}},
  {dataset:{mapFocus:'invalid',x:'bad',y:'0',width:'0',height:'600'}}
];
const svg = {
  viewBox:{baseVal:{width:4410,height:3630}}, clientWidth:390, clientHeight:400,
  setAttribute(k,v){attrs[k]=v},
  querySelectorAll(selector){return selector==='[data-station]' ? allStations : selector==='[data-map-focus]' ? focusAreas : selector==='[data-line]' ? allLines : selector==='[data-legend-line]' ? legends : []},
  addEventListener(name,callback){handlers[name]=callback},
  getBoundingClientRect(){return {left:0,top:0}}, setPointerCapture(){},getScreenCTM(){return null}
};
const document = {getElementById(){return svg},querySelectorAll(selector){return selector==='[data-line]'?allLines:[]},elementFromPoint(){return target}};
const window = {webkit:{messageHandlers:{metro:{postMessage(e){events.push(e)}}}}};
class ResizeObserver {constructor(cb){resizeCallback=cb} observe(){}}
load('App/Resources/Web/map.js');
let count=0;
function check(condition, message){if(!condition)throw new Error(message);count++;}
function box(){return attrs.viewBox.split(' ').map(Number);}
function command(kind,id,target){window.metro.update({command:{kind,id,target}});}
command('focus','1','qianhaiwan');
check(box()[2]===480,'search should zoom into station');
command('in','focus-more');
check(box()[2]<480,'full-network zoom-in after search must not zoom out');
command('focus','focus-again','qianhaiwan');
svg.clientHeight=700;resizeCallback();
check(box()[2]===480,'resize must preserve search zoom');
check(Math.abs(box()[0]+box()[2]/2-600)<.01,'resize preserves horizontal center');
check(Math.abs(box()[1]+box()[3]/2-500)<.01,'resize preserves vertical center');
command('reset','2');
const initial=box()[2];command('in','3');check(box()[2]<initial,'zoom-in must change viewBox');
command('in','3');const once=box()[2];command('in','3');check(box()[2]===once,'same command is idempotent');
command('reset','4');check(box()[2]===initial,'reset restores fitted width');
command('area','area-1','surroundings');
check(Math.abs(box()[2]-900*1.16)<.01,'area focus adds 8 percent margin on each side');
check(Math.abs(box()[0]+box()[2]/2-3450)<.01 && Math.abs(box()[1]+box()[3]/2-500)<.01,'area focus centers its frame');
const focused=box().join(' ');
command('area','area-1','surroundings');check(box().join(' ')===focused,'repeated area command is idempotent');
command('area','area-2','missing');check(box().join(' ')===focused,'unknown area leaves viewport unchanged');
command('area','area-3','invalid');check(box().join(' ')===focused,'invalid area leaves viewport unchanged');
svg.clientWidth=800;svg.clientHeight=300;resizeCallback();
command('area','area-landscape','surroundings');
check(Math.abs(box()[3]-600*1.16)<.01,'wide viewport fits tall area with vertical margin');
command('reset','area-reset-landscape');const landscapeFit=box()[2];
command('area','area-large','oversized');check(box()[2]===landscapeFit,'area focus never exceeds full-map fit');
svg.clientWidth=390;svg.clientHeight=700;resizeCallback();
command('reset','area-reset');check(box()[2]===initial,'reset after area focus restores full map');
command('area','area-legend','legend-lines');
command('focus','station-after-area','qianhaiwan');check(box()[2]===480,'station search still focuses after area navigation');
target=station;
const before=events.length;
handlers.pointerdown({pointerId:1,clientX:100,clientY:100});
handlers.pointermove({pointerId:1,clientX:140,clientY:150});
handlers.pointerup({pointerId:1,clientX:140,clientY:150});
check(events.length===before,'drag must not activate station');
handlers.pointerdown({pointerId:2,clientX:100,clientY:100});
handlers.pointerup({pointerId:2,clientX:100,clientY:100});
check(events[events.length-1].type==='station','station tap emits station before line');
target=null;
handlers.pointerdown({pointerId:3,clientX:300,clientY:300});
handlers.pointerup({pointerId:3,clientX:300,clientY:300});
check(events[events.length-1].type==='blank','blank clears line selection');
for (const selected of ['l8','l2']) {
  window.metro.update({line:selected});
  check(allLines.filter(n=>n.style.opacity==='1').map(n=>n.dataset.line).join(' ')===selected,'2 and 8 must highlight independently, even with legacy highlight metadata');
  check((liantang.style.opacity==='1')===(selected==='l2') && (wutong.style.opacity==='1')===(selected==='l8'),'only selected line stations stay highlighted');
  check((interchange.style.opacity==='1')===(selected==='l2') && allLines.find(n=>n.dataset.line==='l5').style.opacity!== '1','an interchange must not highlight the unrelated line');
}
window.metro.update({line:'l1'});
check(allLines.filter(n=>n.style.opacity==='1').map(n=>n.dataset.line).join(' ')==='l1','ordinary lines remain independently selectable');
window.metro.update({line:null});
check(allLines.every(n=>n.style.opacity==='1') && allStations.every(n=>n.style.opacity==='1'),'clearing selection restores all lines and stations');
const legend=legends.find(n=>n.dataset.legendLine==='l2');
target={closest(selector){return selector==='[data-legend-line]'?legend:null}};
function tap(id){handlers.pointerdown({pointerId:id,clientX:150,clientY:150});handlers.pointerup({pointerId:id,clientX:150,clientY:150});}
const viewBefore=attrs.viewBox;
tap(21);
check(events.at(-1).type==='line' && events.at(-1).id==='l2','legend uses the same line event as map geometry');
window.metro.update({line:'l2'});
check(attrs.viewBox===viewBefore,'legend selection must not move or zoom the map');
check(legend.attrs['aria-pressed']==='true' && legends.filter(n=>n.classList['legend-selected']).length===1,'only selected legend gets a selected appearance');
window.metro.update({line:'l8'});
check(legend.attrs['aria-pressed']==='false' && legends.find(n=>n.dataset.legendLine==='l8').attrs['aria-pressed']==='true','native/list selection updates legend state');
window.metro.update({line:null});
check(legends.every(n=>n.attrs['aria-pressed']==='false'),'cancel clears every legend selection');
let eventCount=events.length;
handlers.pointerdown({pointerId:22,clientX:100,clientY:100});
handlers.pointermove({pointerId:22,clientX:160,clientY:100});
handlers.pointerup({pointerId:22,clientX:160,clientY:100});
check(events.length===eventCount,'drag over legend must not select');
handlers.pointerdown({pointerId:23,clientX:100,clientY:100});
handlers.pointerdown({pointerId:24,clientX:200,clientY:100});
handlers.pointermove({pointerId:24,clientX:240,clientY:100});
handlers.pointerup({pointerId:24,clientX:240,clientY:100});
handlers.pointerup({pointerId:23,clientX:100,clientY:100});
check(events.length===eventCount,'pinch over legend must not select');
handlers.keydown({target,key:'Enter',preventDefault(){}});
check(events.at(-1).id==='l2','keyboard can activate a legend');
print('PASS: '+count+' map interaction checks');
