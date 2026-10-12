#!/usr/bin/env python3
"""Assemble the complete Shenzhen network from versioned official references.
Offline and deterministic; preserves stable station IDs from the original fixture.
"""
import json
from map_context import prepare
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / 'data/shenzhen/references'

def generate():
    fare = json.loads((REF / 'official-fare-stations.json').read_text())
    layout = json.loads((REF / 'schematic-layout.json').read_text())
    registry = json.loads((REF / 'station-ids.json').read_text())
    district_layout = json.loads((REF / 'district-layout.json').read_text())
    district_stations = {s['stationID']: s for s in district_layout['stations']}
    navigation = json.loads((REF / 'amap-station-navigation.json').read_text())
    navigation_stations = {s['stationID']: s for s in navigation['stations']}
    services = json.loads((REF / 'station-services/services.json').read_text())
    names = list(dict.fromkeys(n for l in fare['lines'] for n in l['stations']))
    assert set(names) == set(layout['stations']), '站序与图形位置必须完整对应'
    assert set(names).issubset(registry), '新站必须先在 station-ids.json 分配固定编号；改名时保留原编号'
    ids = {n:registry[n] for n in names}
    assert set(services['stations']) == set(ids.values()), '服务资料必须与固定站点编号一一对应，禁止生成时静默清空'
    assert len(district_stations) == len(district_layout['stations']) and set(district_stations) == set(ids.values()), '分区资料必须与完整线网固定编号一一对应'
    assert len(navigation_stations) == len(navigation['stations']) and set(navigation_stations) == set(ids.values()), '高德导航资料必须与完整线网固定编号一一对应'
    assert district_layout['districts'], '不得丢弃行政区底图'
    lineid = lambda n:'l'+n.replace('支','b')
    # Pronunciations printed on the official map override Foundation's general-purpose
    # character transliteration (厦/孖 have multiple readings).
    pronunciation = {'岗厦':['gangxia','gx'], '岗厦北':['gangxiabei','gxb'],
                     '石厦':['shixia','sx'], '松元厦':['songyuanxia','syx'], '孖岭':['maling','ml']}
    stations=[]
    external = {'湖贝','红岭南','福田口岸'}
    for name in names:
        geo=layout['stations'][name]
        district = district_stations[ids[name]]
        amap = navigation_stations[ids[name]]
        assert amap['name'] == name and amap['system'] == 'gcj02', '高德站名或坐标系不匹配'
        notes=[]
        if name in external: notes.append('官方示意图标注为站外换乘；请留意现场指引及重新进站要求。')
        if name in ['莲塘','梧桐山南']:notes.append('2、8号线贯通运营，莲塘—梧桐山南连接两个编号区段，无须在编号交界下车换乘。')
        stations.append(dict(id=ids[name],name=name,aliases=pronunciation.get(name,[]),districtIDs=district['districtIDs'],districtNote=district['note'],
            lineIDs=[lineid(l['number']) for l in fare['lines'] if name in l['stations']],
            diagram=geo['diagram'],labelOffset=geo['labelOffset'],labelAnchor='start',diagramMarkerPath=geo['markerPath'],
            amapLocation={**{key:amap[key] for key in ['poiID','latitude','longitude','system']}, 'sourceIDs':['amap-subway'], 'updatedAt':navigation['accessedAt']},
            coordinate=None,coordinateSourceIDs=[],**services['stations'][ids[name]],sourceIDs=['official-fare','official-network','amap-subway']+district['sourceIDs'],
            updatedAt=district_layout['reviewedAt'],note=' '.join(notes) or None))
    # Badge positions are schematic units transcribed from the reference's clear margins.
    badges={'1':(983,1190),'2':(107,1320),'8':(1553,868),'3':(622,1242),'4':(859,440),'5':(944,1060),
        '6':(870,1056),'6支':(664,155),'7':(1086,890),'9':(1067,1145),'10':(949,568),'11':(878,1136),
        '12':(124,1375),'13':(445,155),'14':(1535,470),'16':(1262,858),'20':(65,350)}
    lines=[]
    for l in fare['lines']:
        n=l['number'];x,y=badges[n]
        note='与'+('8' if n=='2' else '2')+'号线贯通运营，全程赤湾 ↔ 溪涌，无须在编号交界下车换乘。' if n in ['2','8'] else None
        lines.append(dict(id=lineid(n),name='6号线支线' if n=='6支' else l['name'],shortName=n,color=layout['lineColors'][n],
            stationIDs=[ids[name] for name in l['stations']],termini=l['endpoints'],sourceIDs=['official-fare','official-network'],coverageNote=note,
            diagramPath=layout['linePaths'][n],badgePosition={'x':round(x*4410/1600-50,2),'y':round(y*4410/1600-350,2)}))
    sources=[
        dict(id='official-fare',title='深圳市发展改革委：13号线二期北延开通票价表',url=fare['sourceURL'],accessedAt='2026-09-24',license='政府公开资料；保留来源，仅供本地非商业开发核对；未获得商业再分发授权。',note='2026年6月22日公布、6月28日开通起执行。提取432个线路内站次，按同名站合并为351站；不包含有轨电车、城际和未开通站。'),
        dict(id='official-network',title='深圳政府在线：深圳地铁线路信息及官方线路图',url='https://www.sz.gov.cn/xxgk/sydwxxgk/jt/dt/ywxx/dtxlxx/content/post_11086804.html',accessedAt='2026-09-24',license='来源：深圳政府在线。非商业使用保留原始来源与权利；公开附件不等于开放许可。',note='本站序与官方票价表交叉核对。示意位置、线路走向及颜色参考当前PDF附件；图中13号线标注未开通的西丽高铁、潮汐公园、歌剧院及其南延区段已剔除。图形资料原编制单位为深圳地铁、港铁深圳。'),
        dict(id='opening-13-north',title='深圳市交通运输局：13号线北延段开通',url='https://jtys.sz.gov.cn/ydmh/jtzx/zyhy_1510/content/post_12867344.html',accessedAt='2026-09-24',license='政府公开信息；保留来源。',note='2026年6月28日，上屋至李松蓢11个新增车站开通运营。收录范围以本次核验的运营状态为准，未包含实时变动。')]
    sources.extend(district_layout['sources'])
    sources.extend(services['sources'])
    sources.append(dict(id='amap-subway',title='高德地图：深圳地铁站点导航位置',url=navigation['sourceURL'],accessedAt=navigation['accessedAt'],license='高德公开地图数据；仅供本地非商业开发核对，未获得商业再分发授权。',note=navigation['note']))
    data = dict(schemaVersion=2,cityID='shenzhen',cityName='深圳',version='0.4.0-station-services',dataAsOf='2026-06-28',generatedAt=services['verifiedAt'],isSample=False,
        coverageNote='已收录官方票价表17条编号线路、351站（432个线路内站次），含68个多线站；2/8贯通。保留10个浅色分区和站点详情中的区属疑点。351站已收录高德站点编号与GCJ02位置；首末班和出口按本站资料分别显示收录状态，冲突记录暂不展示。出口不保证全部齐全；暂无精确出口坐标及通用WGS84站点坐标。',
        disclaimer='线路位置为示意，不代表真实距离。收录状态截止2026-06-28，2026-09-24核对资料；未包含实时调整。来源：深圳政府在线、深圳市发展改革委；仅供个人非商业开发使用。',
        map=dict(width=layout['width'],height=layout['height'],stationLabelFontSize=27),districts=district_layout['districts'],lines=lines,stations=stations,sources=sources,
        networkReview=dict(reviewedAt='2026-09-24',sourceIDs=['official-fare','official-network','opening-13-north'],lineCount=17,stationCount=351,membershipCount=432),
        throughServices=[dict(fromStationID=ids['莲塘'],toStationID=ids['梧桐山南'],lineIDs=['l2','l8'],note='2、8号线贯通运营，无须在编号交界下车换乘。')])

    return prepare(data, json.loads((REF / 'map-context.json').read_text()))

if __name__=='__main__':
    from citypack import validate
    data=generate();validate(data)
    (ROOT/'data/shenzhen/source.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print(f"生成 {len(data['lines'])} 条线路 / {len(data['stations'])} 站")
