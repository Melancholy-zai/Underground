#!/usr/bin/env python3
"""Cache public MTR Shenzhen source material; never treats OCR as verified data.

Use --fetch to make bounded, sequential requests; existing successful downloads
are reused. HTTP/access failures are recorded and not retried or bypassed.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
from datetime import datetime
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'data/shenzhen/references/station-services/operator'
ORIGIN = 'https://www.mtrsz.com.cn'

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def fetch_sources():
    audit_path = BASE / 'fetch-audit.json'
    audit = json.loads(audit_path.read_text()) if audit_path.exists() else {}
    def get(url, rel):
        path = BASE / rel
        if path.exists() and rel in audit and audit[rel]['status'] == 'ok':
            return path
        if rel in audit and audit[rel]['status'] != 'ok':
            return None
        path.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(['curl','-L','--fail','--silent','--show-error','--max-time','30',url,'-o',str(path)], capture_output=True, text=True)
        now = datetime.now(ZoneInfo('Asia/Shanghai')).isoformat()
        audit[rel] = {'url':url,'retrievedAt':now,'status':'ok' if result.returncode == 0 else 'failed','error':result.stderr or None}
        if result.returncode == 0:
            audit[rel]['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        write(audit_path,audit)
        time.sleep(0.7)
        return path if result.returncode == 0 else None
    stations=[]
    for line, channel in [('l4',7590),('l13',7591)]:
        path=get(f'{ORIGIN}/server-front/front/content/page?channelIdStr={channel}&pageSize=100&orderBy=0',f'raw/directory-{line}.json')
        if not path: continue
        records=json.loads(path.read_text())['data']['records']
        stations.extend(dict(x,lineID=line) for x in records if x['title'] != '车站无障碍设施')
    entries=[]
    for item in stations + [{'id':9115,'title':'4号线运营时刻表','lineID':'l4'}, {'id':9116,'title':'13号线运营时刻表','lineID':'l13'}]:
        cid=item['id']
        path=get(f'{ORIGIN}/server-front/front/content/detail?id={cid}', f'raw/detail-{cid}.json')
        if not path: continue
        detail=json.loads(path.read_text())['data']
        fields=next(x['value'] for x in detail['instance']['instanceItems'] if x['field']=='contents')
        section='正文' if cid in [9115,9116] else 'content1'
        images=[]
        for index, src in enumerate(re.findall(r'<img[^>]+src="([^"]+)"',fields.get(section,''))):
            url=ORIGIN+src if src.startswith('/') else src
            rel=f'images/{cid}-{index}{Path(src).suffix}'
            image_path=get(url,rel)
            images.append({'url':url,'path':rel,'status':'cached' if image_path else 'failed','visualReviewStatus':'pending'})
        entries.append({'articleID':cid,'title':item['title'],'lineID':item['lineID'],'sourcePublishedAtRaw':detail.get('publishTime'),'section':section,'images':images})
        write(BASE/'image-index.json',entries)
        print(item['title'],len(images),flush=True)

def build_services():
    """Normalize only explicitly reviewed, hash-locked images and transcriptions."""
    review=json.loads((BASE/'visual-review.json').read_text())
    verified=review['verifiedAt']
    for rel, expected in review['reviewedImageSHA256'].items():
        actual=hashlib.sha256((BASE/rel).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f'Source image changed; visual re-review required: {rel}')
    fetch=json.loads((BASE/'fetch-audit.json').read_text())
    index=json.loads((BASE/'image-index.json').read_text())
    mapping={(r['lineID'],r['stationName']):r['stationID'] for r in csv.DictReader((ROOT/'docs/research/station-services-2026-09-28/station-source-index.csv').open(encoding='utf-8-sig'))}
    reviewed_exits=json.loads((BASE/'exits-reviewed.json').read_text())
    sources=[]
    stations={}
    def add_source(item, image_index, source_id, title):
        img=item['images'][image_index]
        sources.append({'id':source_id,'title':title,'url':img['url'],
            'accessedAt':fetch[img['path']]['retrievedAt'][:10],
            'sourcePublishedAt':item['sourcePublishedAtRaw'][:10] if item['sourcePublishedAtRaw'] else None,
            'license':'港铁深圳官方网站公开资料；未核实批量复用或再分发许可',
            'note':'发布时间来自所属文章元数据，不表示时刻生效日期或图片制作日期。目视核读仅确认原图内容，不表示出口实时开放。'})
        return {'sourceID':source_id,'sourceURL':img['url'],'sourcePath':img['path'],
            'sha256':fetch[img['path']]['sha256'],'accessedAt':fetch[img['path']]['retrievedAt'][:10],
            'sourcePublishedAtRaw':item['sourcePublishedAtRaw'],'verifiedAt':verified,'method':'visual_image_review'}
    table_items={x['lineID']:x for x in index if x['articleID'] in [9115,9116]}
    table_provenance={line:add_source(x,0,f'mtrsz-timetable-{line}',x['title']) for line,x in table_items.items()}
    for item in index:
        if item['articleID'] in [9115,9116]: continue
        cid=str(item['articleID'])
        sid=mapping[(item['lineID'],item['title'])]
        provenance=add_source(item,1,f'mtrsz-station-{cid}-index',f'港铁深圳{item["title"]}站地点—出口索引')
        output=dict(reviewed_exits[cid])
        map_provenance=None
        if cid in review['mapExitNumbers']:
            image_type=review.get('mapImageTypeOverrides',{}).get(cid,'周边图')
            map_provenance=add_source(item,0,f'mtrsz-station-{cid}-map',f'港铁深圳{item["title"]}站{image_type}')
        # The index bus section abbreviates C; map resolves real C1/C2 entrances.
        if cid == '9700':
            output.pop('C')
        # The Xiacun index uses A while the station map labels A1. Do not
        # silently transfer landmark claims to a differently labelled exit.
        if cid == '13517':
            output.pop('A')
        map_only=[]
        for number in review['mapExitNumbers'].get(cid,[]):
            if number not in output:
                output[number]=None
                map_only.append(number)
        exits=[]
        for number,description in sorted(output.items()):
            refs=[map_provenance['sourceID']] if number in map_only else [provenance['sourceID']]
            annotation=review.get('mapExitAnnotations',{}).get(cid,{}).get(number)
            if annotation:
                description=(description+'；' if description else '')+f'原图标注“{annotation}”（实时状态未确认）'
                if map_provenance['sourceID'] not in refs: refs.append(map_provenance['sourceID'])
            exits.append({'id':f'{sid}-exit-{number.lower()}','name':number+'出口','description':description,
                'coordinate':None,'sourceIDs':refs,'updatedAt':verified,'verifiedAt':verified})
        stations[sid]={'timetables':[],'exits':exits,'audit':{
            'stationName':item['title'],'articleID':item['articleID'],'lineID':item['lineID'],
            'exitProvenance':provenance,'mapProvenance':map_provenance,
            'rawExitTranscription':reviewed_exits[cid],
            'mapExitNumbers':review['mapExitNumbers'].get(cid,[]),'mapOnlyExitNumbers':map_only,
            'mapExitAnnotations':review.get('mapExitAnnotations',{}).get(cid,{}),
            'exitCompleteness':'partial: all source-map entrance numbers reviewed; selected index landmarks transcribed; live opening status unconfirmed',
            'gaps':['未确认出口实时开放状态；无经纬度。','地点说明按索引摘录，不代表周边地图全部地点。']}}
        if cid not in review['mapExitNumbers']:
            stations[sid]['audit']['gaps'].append('周边图已缓存，但尚未逐一核对图上全部出口编号。')
        if cid=='9700':
            stations[sid]['audit']['exitResolution']={'raw':'索引公交栏目C；学校栏目C1','map':'周边图C1/C2',
                'decision':'正式出口保留C1、新增图上C2；公交C留在原始核验层，不作为额外出口。','verifiedAt':verified}
        if cid=='9698':
            stations[sid]['audit']['exitResolution']={'raw':'索引A/A2','map':'周边图A/A2',
                'decision':'两张图一致，保留A与A2，不自行改成A1。','verifiedAt':verified}
        if cid=='13517':
            stations[sid]['audit']['exitResolution']={'raw':'索引A','map':'周边图A1',
                'decision':'正式编号采用图上A1；原索引A及地点保留在核验层，未将其地点移植到A1。','verifiedAt':verified}
            stations[sid]['audit']['gaps'].append('下村A与A1存在图文编号差异，A1地点说明留空，待运营方确认。')
        stations[sid]['serviceReview']={'timetableStatus':'reviewed','exitStatus':'partial','note':'按运营方原图核读。出口地点为索引摘录，完整性及实时开放状态未确认。','verifiedAt':verified}
    rows=list(csv.DictReader((BASE/'timetables-reviewed.csv').open()))
    assert len(rows)==49
    def clock(raw,is_last=False):
        if raw=='---': return None
        hour,minute=map(int,raw.split(':'))
        assert 0<=hour<=23 and 0<=minute<=59
        # Both reviewed tables show daytime starts and overnight last services.
        return {'clock':f'{hour:02}:{minute:02}','dayOffset':1 if is_last and hour<4 else 0}
    for row in rows:
        line=row['lineID']; sid=mapping[(line,row['stationName'])]
        service_days='平日和周末' if line=='l4' else '来源未注明适用日'
        directions=['福田口岸','牛湖'] if line=='l4' else ['李松蓢','深圳湾口岸']
        short_dests=['龙华','清湖']
        stations[sid]['audit']['rawTimetableRow']={'values':row,'provenance':table_provenance[line],
            'columnDirections':directions,'shortLastDestinations':short_dests if line=='l4' else [],
            'stationNameRaw':'深圳北' if row['stationName']=='深圳北站' else row['stationName']+('站' if line=='l13' else ''),
            'rowNumber':rows.index(row)+1 if line=='l4' else rows.index(row)-22,
            'excludedColumns':['open','close'],'directionStatus':{}}
        for i,direction in enumerate(directions,1):
            first=clock(row[f'firstDirection{i}']);last=clock(row[f'lastDirection{i}'],True)
            status='available' if first or last else 'notApplicable'
            stations[sid]['audit']['rawTimetableRow']['directionStatus'][direction]=status
            if status=='notApplicable':
                assert row['stationName']==direction, 'Only visually confirmed terminal-direction dash rows may be not applicable'
                continue
            for label,dest,f,l in [('全程',direction,first,last),('半程加班车',short_dests[i-1],None,clock(row[f'shortLastDirection{i}'],True))]:
                if not f and not l: continue
                identity='|'.join([sid,line,direction,service_days,label,dest])
                stations[sid]['timetables'].append({'id':'mtrsz-'+hashlib.sha256(identity.encode()).hexdigest()[:20],
                    'lineID':line,'direction':direction,'serviceDays':service_days,'validFrom':None,'validThrough':None,
                    'first':f,'last':l,'lastDestination':dest,'serviceLabel':label,
                    'note':'运营方表提示：距末班车编定开出时间不足5分钟时，乘客可能不能入闸。生效日期未注明。',
                    'sourceIDs':[table_provenance[line]['sourceID']],'updatedAt':verified,'verifiedAt':verified})
    result={'sources':sources,'stations':stations,'audit':{
        'verifiedAt':verified,'method':'逐行目视核读两张完整时刻表；逐图目视核读49站地点—出口索引；49站周边图或立体图出口号交叉核读。',
        'stationCount':len(stations),'timetableCount':sum(len(s['timetables']) for s in stations.values()),
        'exitCount':sum(len(s['exits']) for s in stations.values()),'indexReviewedCount':len(reviewed_exits),'mapExitNumbersReviewedCount':len(review['mapExitNumbers']),
        'usageRightsConfirmed':False,'validFromKnown':False,'gaps':['未穷尽临时公告；来源未明确生效日。','下村索引A与地图A1编号有差异；原值及处理见该站audit。','索引地点为摘录；出口实时开放状态未确认。'],
        'reviewManifest':'visual-review.json','rawTimetableTranscription':'timetables-reviewed.csv','rawExitTranscription':'exits-reviewed.json'}}
    assert len(stations)==49
    write(BASE/'services.json',result)
    print(json.dumps({k:v for k,v in result['audit'].items() if k.endswith('Count')},ensure_ascii=False))

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true')
    parser.add_argument('--build', action='store_true')
    args=parser.parse_args()
    if args.fetch: fetch_sources()
    if args.build: build_services()
