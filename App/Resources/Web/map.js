(() => {
  'use strict';
  const svg = document.getElementById('metro-map');
  const bounds = svg.viewBox.baseVal;
  const natural = {width: bounds.width, height: bounds.height};
  let view = {x: 0, y: 0, width: natural.width, height: natural.height};
  let fitWidth = natural.width, gesture = null, moved = false, lastCommand = null;
  const pointers = new Map();
  const lines = Array.from(svg.querySelectorAll('[data-line]'));
  const legends = Array.from(svg.querySelectorAll('[data-legend-line]'));
  const stations = Array.from(svg.querySelectorAll('[data-station]'));
  const focusAreas = Array.from(svg.querySelectorAll('[data-map-focus]'));
  function post(type, id) {
    window.webkit?.messageHandlers?.metro?.postMessage({type, id: id || ''});
  }
  function apply() { svg.setAttribute('viewBox', `${view.x} ${view.y} ${view.width} ${view.height}`); }
  function reset() {
    const aspect = svg.clientWidth / Math.max(svg.clientHeight, 1);
    let width = natural.width * 1.1, height = width / aspect;
    if (height < natural.height * 1.1) { height = natural.height * 1.1; width = height * aspect; }
    fitWidth = width;
    view = {x: (natural.width-width)/2, y: (natural.height-height)/2, width, height};
    apply();
  }
  function point(clientX, clientY) {
    const rect = svg.getBoundingClientRect();
    return {x: clientX-rect.left, y: clientY-rect.top};
  }
  function zoom(factor, anchor = {x: svg.clientWidth/2, y: svg.clientHeight/2}) {
    const width = Math.min(fitWidth, Math.max(Math.min(180,fitWidth/10), view.width * factor));
    const ratio = width/view.width;
    view.x += anchor.x/svg.clientWidth*view.width*(1-ratio);
    view.y += anchor.y/svg.clientHeight*view.height*(1-ratio);
    view.width = width; view.height *= ratio; apply();
  }
  function startGesture() {
    const points = Array.from(pointers.values());
    if (points.length >= 2) {
      moved = true;
      const a = points[0], b = points[1];
      const middle = {x:(a.x+b.x)/2,y:(a.y+b.y)/2};
      gesture = {kind:'pinch', distance:Math.max(1, Math.hypot(a.x-b.x,a.y-b.y)),
        view:{...view}, world:{x:view.x+middle.x/svg.clientWidth*view.width,y:view.y+middle.y/svg.clientHeight*view.height}};
    } else if (points.length === 1) {
      gesture = {kind:'pan', start: points[0], view:{...view}};
    } else gesture = null;
  }
  svg.addEventListener('pointerdown', event => {
    if (pointers.size === 0) moved = false;
    pointers.set(event.pointerId, point(event.clientX,event.clientY));
    svg.setPointerCapture(event.pointerId); startGesture();
  });
  svg.addEventListener('pointermove', event => {
    if (!pointers.has(event.pointerId) || !gesture) return;
    pointers.set(event.pointerId, point(event.clientX,event.clientY));
    const points = Array.from(pointers.values());
    if (gesture.kind === 'pinch' && points.length >= 2) {
      const a=points[0], b=points[1], middle={x:(a.x+b.x)/2,y:(a.y+b.y)/2};
      const width = Math.min(fitWidth, Math.max(Math.min(180,fitWidth/10), gesture.view.width*gesture.distance/Math.max(1,Math.hypot(a.x-b.x,a.y-b.y))));
      const height = width*svg.clientHeight/svg.clientWidth;
      view = {x:gesture.world.x-middle.x/svg.clientWidth*width,y:gesture.world.y-middle.y/svg.clientHeight*height,width,height};
    } else if (gesture.kind === 'pan') {
      const dx=points[0].x-gesture.start.x, dy=points[0].y-gesture.start.y;
      if (Math.hypot(dx,dy) > 7) moved = true;
      view.x = gesture.view.x-dx/svg.clientWidth*gesture.view.width;
      view.y = gesture.view.y-dy/svg.clientHeight*gesture.view.height;
    }
    apply();
  });
  function hit(event) {
    // Pointer capture changes event.target; inspect the actual element under the finger.
    const target = document.elementFromPoint(event.clientX,event.clientY);
    const station = target?.closest('[data-station]');
    if (station) { post('station',station.dataset.station); return; }
    const legend = target?.closest('[data-legend-line]');
    if (legend) { post('line',legend.dataset.legendLine); return; }
    const matrix = svg.getScreenCTM();
    let best = null, distance = matrix ? Math.min(22, Math.max(6, 22*Math.hypot(matrix.a,matrix.b))) : 22;
    if (matrix) stations.forEach(node => {
      const screen = new DOMPoint(Number(node.dataset.x),Number(node.dataset.y)).matrixTransform(matrix);
      const d = Math.hypot(screen.x-event.clientX,screen.y-event.clientY);
      if(d < distance){distance=d;best=node;}
    });
    if(best){post('station',best.dataset.station);return;}
    const line = target?.closest('[data-line]');
    post(line ? 'line' : 'blank',line?.dataset.line);
  }
  svg.addEventListener('pointerup', event => {
    if (!pointers.has(event.pointerId)) return;
    const shouldHit = pointers.size === 1 && !moved;
    pointers.delete(event.pointerId);
    if (shouldHit) hit(event);
    startGesture();
  });
  svg.addEventListener('pointercancel', event => {pointers.delete(event.pointerId);moved=true;startGesture();});
  svg.addEventListener('wheel', event => {event.preventDefault();zoom(Math.exp(event.deltaY*0.002),point(event.clientX,event.clientY));},{passive:false});
  svg.addEventListener('keydown', event => {
    const station = event.target.closest('[data-station]');
    const legend = event.target.closest('[data-legend-line]');
    if ((station || legend) && (event.key==='Enter'||event.key===' ')){
      event.preventDefault();post(station ? 'station' : 'line',station?.dataset.station || legend.dataset.legendLine);
    }
  });
  window.metro = {
    update(state) {
      const activeLines = new Set(state.line ? [state.line] : []);
      legends.forEach(node => {
        const selected = node.dataset.legendLine === state.line;
        node.classList.toggle('legend-selected',selected);
        node.setAttribute('aria-pressed',String(selected));
      });
      lines.forEach(node => {node.style.opacity = !state.line || activeLines.has(node.dataset.line) ? '1' : '.16';});
      stations.forEach(node => {
        node.classList.toggle('selected',node.dataset.station===state.station);
        node.style.opacity = !state.line || node.dataset.lines.split(' ').some(id => activeLines.has(id)) || node.dataset.station===state.station ? '1' : '.32';
      });
      const command=state.command;
      if (!command || command.id===lastCommand) return;
      lastCommand=command.id;
      if(command.kind==='reset')reset();
      if(command.kind==='in')zoom(.65);
      if(command.kind==='out')zoom(1/.65);
      if(command.kind==='area'){
        const area=focusAreas.find(node=>node.dataset.mapFocus===command.target);
        if(area){
          const frame={x:Number(area.dataset.x),y:Number(area.dataset.y),width:Number(area.dataset.width),height:Number(area.dataset.height)};
          if(Object.values(frame).every(Number.isFinite) && frame.width>0 && frame.height>0){
            const aspect=svg.clientWidth/Math.max(svg.clientHeight,1);
            const width=Math.min(fitWidth,Math.max(frame.width,frame.height*aspect)*1.16),height=width/aspect;
            view={x:frame.x+(frame.width-width)/2,y:frame.y+(frame.height-height)/2,width,height};apply();
          }
        }
      }
      if(command.kind==='focus'){
        const station=stations.find(node=>node.dataset.station===command.target);
        if(station){
          const width=Math.min(fitWidth,480),height=width*svg.clientHeight/svg.clientWidth;
          view={x:Number(station.dataset.x)-width/2,y:Number(station.dataset.y)-height/2,width,height};apply();
        }
      }
    }
  };
  // Keyboard dismissal and native footer changes resize WebKit. Preserve the user's
  // world center and horizontal zoom; resizing is not an explicit reset command.
  new ResizeObserver(() => {
    const center = {x:view.x+view.width/2, y:view.y+view.height/2};
    const aspect = svg.clientWidth/Math.max(svg.clientHeight,1);
    fitWidth = Math.max(natural.width*1.1,natural.height*1.1*aspect);
    const width = Math.min(fitWidth,view.width), height = width/aspect;
    view = {x:center.x-width/2,y:center.y-height/2,width,height};
    apply();
  }).observe(svg);
  reset(); post('ready');
})();
