"""Source-backed geographic context and legends, independent of transit geometry."""
import copy
import html
import math
import re
from datetime import date

ESC=lambda v:html.escape(str(v),quote=True)

def translate_path(path, dx, dy):
    # Official reference uses absolute M/L/C/Z; reject any unsupported geometry.
    out=[]
    for command, args in re.findall(r'([MLCZ])([^MLCZ]*)',path):
        values=[float(v) for v in args.replace(',',' ').split()]
        out.append(command+' '+' '.join(f'{v+(dx if i%2==0 else dy):.2f}' for i,v in enumerate(values)))
    return ' '.join(out).strip()


def prepare(data, reference):
    dx,dy=reference['networkOffset']['x'],reference['networkOffset']['y']
    def move(p):p.update(x=round(p['x']+dx,2),y=round(p['y']+dy,2))
    for s in data['stations']:
        move(s['diagram'])
        if s.get('diagramMarkerPath'):s['diagramMarkerPath']=translate_path(s['diagramMarkerPath'],dx,dy)
    for line in data['lines']:
        if line.get('badgePosition'):move(line['badgePosition'])
        if line.get('diagramPath'):line['diagramPath']=translate_path(line['diagramPath'],dx,dy)
    for district in data['districts']:
        move(district['label'])
        for point in district['polygon']:move(point)
    data['map'].update(reference['canvas'])
    data['mapContext']=copy.deepcopy(reference['mapContext'])
    data['sources'].extend(copy.deepcopy(reference['sources']))
    data['networkReview']['reviewedAt']=data['mapContext']['reviewedAt']
    data['networkReview']['sourceIDs'].append('network-check-202609')
    return data


def validate_context(data):
    c=data.get('mapContext')
    if c is None:return
    def need(ok,message):
        if not ok:raise ValueError('外围资料：'+message)
    def text(v):return isinstance(v,str) and bool(v.strip())
    def number(v):return type(v) in (int,float) and math.isfinite(v)
    def point(p):need(isinstance(p,dict) and all(number(p.get(k)) for k in ('x','y')),'坐标无效')
    def frame(f):
        need(isinstance(f,dict) and all(number(f.get(k)) for k in ('x','y','width','height')),'聚焦框无效')
        need(f['width']>0 and f['height']>0 and f['x']>=0 and f['y']>=0 and f['x']+f['width']<=data['map']['width'] and f['y']+f['height']<=data['map']['height'],'聚焦框越界')
    sources={s['id'] for s in data['sources']}
    def refs(v):need(isinstance(v,list) and v and all(isinstance(s,str) and s in sources for s in v),'来源缺失')
    def unique(items):
        need(isinstance(items,list) and all(isinstance(i,dict) and text(i.get('id')) for i in items),'对象缺少编号')
        need(len({i['id'] for i in items})==len(items),'重复编号')
    def area(a):
        need(text(a.get('name')) and a.get('kind') in ('neighbor','water','home','acrossWater'),'区域类型无效')
        need(isinstance(a.get('polygon'),list) and len(a['polygon'])>=3,'区域缺少轮廓')
        for p in a['polygon']:point(p)
        point(a.get('label'));refs(a.get('sourceIDs'));need(isinstance(a.get('note'),str),'区域缺少说明')
    need(isinstance(c,dict),'应为对象');refs(c.get('sourceIDs'))
    need(text(c.get('note')),'缺少声明')
    try:date.fromisoformat(c['reviewedAt'])
    except (ValueError,KeyError,TypeError):raise ValueError('外围资料：复核日期无效')
    frame(c.get('networkFrame'))
    for field in ('areas','boundaries','insets','focusAreas','annotations'):unique(c.get(field))
    for a in c['areas']:area(a)
    for a in c['annotations']:
        point(a.get('position'));refs(a.get('sourceIDs'))
        need(text(a.get('text')) and number(a.get('fontSize')) and a['fontSize']>0,'说明文字无效')
    for b in c['boundaries']:
        need(b.get('kind') in ('city','region','coast'),'边界类型无效')
        need(isinstance(b.get('points'),list) and len(b['points'])>=2,'边界至少两个点')
        for p in b['points']:point(p)
        need(isinstance(b.get('sides'),list) and len(b['sides'])==2 and all(text(s) for s in b['sides']),'必须说明边界两侧')
        refs(b.get('sourceIDs'));need(text(b.get('note')),'边界缺少说明')
        if b.get('label') is not None:point(b['label'])
    for inset in c['insets']:
        need(text(inset.get('title')) and text(inset.get('note')),'插图缺少说明')
        frame(inset.get('frame'));refs(inset.get('sourceIDs'));unique(inset.get('areas'))
        for a in inset['areas']:area(a)
    for f in c['focusAreas']:frame(f.get('frame'));need(text(f.get('title')),'聚焦框缺少标题')
    stations={s['id']:s for s in data['stations']}
    need(isinstance(c.get('stationNotes'),list),'缺少临界站说明')
    seen=set()
    for n in c['stationNotes']:
        need(n.get('stationID') in stations and n['stationID'] not in seen,'站点说明引用无效')
        seen.add(n['stationID']);refs(n.get('sourceIDs'))
        need(text(n.get('text')) and text(n.get('marker')),'站点说明为空')
    need({s['id'] for s in data['stations'] if not s['districtIDs']}.issubset(seen),'未定区属站缺少配套说明')


def txt(x,y,value,size=44,fill='#344e50',anchor='start',weight=400,extra=''):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" style="font-size:{size}px;fill:{fill};font-weight:{weight}" {extra}>{ESC(value)}</text>'


def polygon(points,fill,stroke='none',width=2):
    return f'<polygon points="{" ".join(str(p["x"])+","+str(p["y"]) for p in points)}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def render_background(data):
    c=data.get('mapContext')
    if not c:return ''
    out=['<g id="map-context-background" pointer-events="none" aria-hidden="true">']
    for a in c['areas']:
        fill='#dfedf1' if a['kind']=='water' else '#e9eeeb'
        out.append(f'<g data-map-area="{ESC(a["id"])}"><title>{ESC(a["note"])}</title>'+polygon(a['polygon'],fill)+'</g>')
    out.append('</g>')
    return '\n'.join(out)


def render_boundaries(data):
    c=data.get('mapContext')
    if not c:return ''
    out=['<g id="map-boundaries" pointer-events="none" aria-hidden="true">']
    for b in c['boundaries']:
        color='#438395' if b['kind']=='coast' else '#687078'
        dash='' if b['kind']=='coast' else ' stroke-dasharray="24 15"'
        points=' '.join(f'{p["x"]},{p["y"]}' for p in b['points'])
        out.append(f'<g data-boundary="{b["id"]}" data-boundary-kind="{b["kind"]}"><title>{ESC(b["note"])}</title><polyline points="{points}" fill="none" stroke="{color}" stroke-width="7" stroke-linejoin="round"{dash}/></g>')
    out.append('</g>');return '\n'.join(out)


def render_foreground(data):
    c=data.get('mapContext')
    if not c:return ''
    out=['<g id="map-context-foreground" pointer-events="none" aria-hidden="true">']
    out.append(txt(100,120,'深圳地铁 · 行政分区与周边关系',78,weight=700))
    for a in c['areas']:
        size=76 if a['kind']=='neighbor' else 64
        x,y=a['label']['x'],a['label']['y']
        extra=f'transform="rotate(90 {x} {y})"' if a['id']=='daya-bay' else ''
        out.append(txt(x,y,a['name'],size,fill='#547982' if a['kind']=='water' else '#566b68',anchor='middle',weight=600,extra=extra))
    for a in c['annotations']:
        for j,line in enumerate(a['text'].split('\n')):out.append(txt(a['position']['x'],a['position']['y']+j*(a['fontSize']+20),line,a['fontSize'],anchor='middle'))
    for b in c['boundaries']:
        if not b['label']:continue
        x,y=b['label']['x'],b['label']['y']
        extra=f'transform="rotate(90 {x} {y})"' if b['id']=='sz-hz' else ''
        out.append(txt(x,y,' / '.join(b['sides'])+' · 示意交界',30,anchor='middle',extra=extra))
    out += [txt(5140,100,'N',48,anchor='middle',weight=700),'<path d="M 5140 165 L 5140 125 M 5120 145 L 5140 125 L 5160 145" fill="none" stroke="#344e50" stroke-width="6"/>']
    # Context cards sit above the network; no right-hand sidebar.
    for inset in c['insets']:
        f=inset['frame'];x,y,w,h=[f[k] for k in ('x','y','width','height')]
        out.append(f'<g data-map-inset="{inset["id"]}">')
        out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="25" fill="white" stroke="#cbd8d5" stroke-width="3"/>')
        out.append(txt(x+35,y+65,inset['title'],54,weight=650))
        scale=.34 if inset['id']=='location' else .7
        out.append(f'<g transform="translate({x+30},{y+85}) scale({scale})">')
        for a in inset['areas']:
            fill={'water':'#dfedf1','home':'#c8dfcb','neighbor':'#edf0e9','acrossWater':'#eef0e9'}[a['kind']]
            out.append(polygon(a['polygon'],fill,'#8dada6',3))
            p=a['label'];out.append(txt(p['x'],p['y'],a['name'],70,anchor='middle',weight=650 if a['kind']=='home' else 450))
        out.append('</g>')
        note_x=x+(580 if inset['id']=='location' else 1100)
        for j,line in enumerate(inset['note'].split('\n')):out.append(txt(note_x,y+165+j*78,line,44))
        out.append('</g>')
    # Legends have distinct IDs so geometry verification and fading stay independent.
    out.append('</g><g id="legend-lines">')
    out.append('<style>.line-legend{cursor:pointer}.legend-hit{fill:transparent;stroke:transparent;stroke-width:5}.legend-selected .legend-hit{fill:#e7f1e9;stroke:#24604e}</style>')
    out.append(txt(110,4715,'线路',52,weight=650))
    for i,line in enumerate(sorted(data['lines'], key=lambda line:(int(line['shortName'].replace('支','')), '支' in line['shortName']))):
        xx=370+(i%9)*545;yy=4715+(i//9)*115
        out.append(f'<g data-legend-line="{line["id"]}" class="line-legend" role="button" tabindex="0" aria-label="{ESC(line["name"])}图例" aria-pressed="false"><rect class="legend-hit" x="{xx-16}" y="{yy-70}" width="510" height="108" rx="16"/>')
        out.append(f'<rect pointer-events="none" x="{xx}" y="{yy-45}" width="84" height="61" rx="9" fill="{line["color"]}"/>')
        out.append(txt(xx+42,yy,line['shortName'],38,fill='white',anchor='middle',weight=700))
        out.append(txt(xx+104,yy,line['name'],48))
        out.append('</g>')
    out.append('</g>')
    out.append('<g id="legend-symbols" pointer-events="none" aria-hidden="true">')
    out.append(txt(110,4990,'符号',52,weight=650))
    symbols=[('ordinary','普通站'),('transfer','换乘站'),('external','站外换乘'),('district','示意区界'),('city','市界 / 深港界线'),('coast','海岸线 / 水域')]
    for i,(kind,label) in enumerate(symbols):
        xx=370+i*820;yy=4990
        if kind=='ordinary':out.append(f'<circle cx="{xx+35}" cy="{yy-12}" r="12" fill="white" stroke="#34534b" stroke-width="4"/>')
        elif kind in ('transfer','external'):
            out.append(f'<rect x="{xx}" y="{yy-30}" width="72" height="32" rx="16" fill="white" stroke="#34534b" stroke-width="4"/>')
            if kind=='external':out.append(txt(xx+89,yy,'↗',37))
        else:
            dash=' stroke-dasharray="15 9"' if kind=='city' else ''
            color={'city':'#687078','coast':'#438395','district':'#aabbb1'}[kind]
            width=3 if kind=='district' else 6
            out.append(f'<path d="M{xx} {yy-14} h100" stroke="{color}" stroke-width="{width}" fill="none"{dash}/>')
        out.append(txt(xx+132,yy,label,44))
    out.append(txt(110,5090,'2 / 8 号线贯通运营 · 站外换乘请按现场指引 · 大鹏新区按管理范围标示',38))
    out.append(txt(110,5160,c['note'],34))
    out.append('</g>')
    for f in c['focusAreas']:
        r=f['frame'];out.append(f'<g data-map-focus="{f["id"]}" data-x="{r["x"]}" data-y="{r["y"]}" data-width="{r["width"]}" data-height="{r["height"]}"/>')
    return '\n'.join(out)
