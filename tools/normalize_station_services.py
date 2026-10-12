#!/usr/bin/env python3
"""Offline normalization of cached official responses and visually reviewed operator data.
No static HTML fallback, time interpolation, or last-writer-wins merging.
"""
import csv
import hashlib
import json
from collections import defaultdict, Counter
from pathlib import Path
import re
from collect_station_services import read_index, STORE, ROOT

DAYS = {'workDay': '工作日', 'dayoff': '休息日', 'holidays': '节假日参考（具体适用日期未注明，以专项公告为准）'}

def stable_id(*parts):
    return 'svc-' + hashlib.sha256('|'.join(parts).encode()).hexdigest()[:20]

def clock(value, last=False):
    value = str(value or '').strip()
    if value in ('', '--', '---', '无'): return None
    match = re.fullmatch(r'(\d{1,2}):(\d{2})', value)
    if not match: raise ValueError('非精确时间，不转换：' + value)
    h, m = map(int, match.groups())
    if not 0 <= h <= 26 or not 0 <= m < 60: raise ValueError('时间越界：' + value)
    offset = int(h >= 24 or (last and h < 4))
    return dict(clock=f'{h%24:02d}:{m:02d}', dayOffset=offset)

def exit_names(raw):
    value = re.sub(r'（.*?）|\(.*?\)', '', raw.strip())
    value = re.sub(r'(号)?(出入口|出口|口)$', '', value).strip()
    result = []
    for part in re.split(r'[、/，,]', value):
        part = part.strip()
        interval = re.fullmatch(r'(\d+)-(\d+)', part)
        if interval and 0 < int(interval[1]) <= int(interval[2]) < 100:
            result.extend(str(i) for i in range(int(interval[1]), int(interval[2])+1))
        elif part: result.append(part.upper())
    return result

def signature(t):
    return json.dumps([t.get('first'), t.get('last')], sort_keys=True)

def normalize():
    city = json.loads((ROOT/'data/shenzhen/source.json').read_text())
    stations = {s['id']: s for s in city['stations']}
    candidates, exits, gaps = defaultdict(list), defaultdict(list), defaultdict(list)
    audit, sources, requests = [], {}, defaultdict(list)
    verified_dates = set()
    for row in read_index():
        code, sid = row['sourceStationCode'], row['stationID']
        path, meta = STORE/'raw'/f'{code}.json', STORE/'requests'/f'{code}.json'
        if not path.exists() or not meta.exists():
            gaps[sid].append(dict(kind='request', lineID=row['lineID'], reason=f'查询{code}未取得响应')); continue
        info = json.loads(meta.read_text()); requests[sid].append(info)
        if info['status'] != 'fetched' or info.get('sha256') != hashlib.sha256(path.read_bytes()).hexdigest():
            gaps[sid].append(dict(kind='request', lineID=row['lineID'], reason=f'查询{code}失败或缓存哈希不符')); continue
        raw = json.loads(path.read_text()); date = info['retrievedAt'][:10]; verified_dates.add(date)
        if str(raw['siteCode']) != code or raw['siteName'].removesuffix('站') != row['stationName'].removesuffix('站'):
            gaps[sid].append(dict(kind='identity', lineID=row['lineID'], reason=f'查询{code}站点身份不符')); continue
        source = 'szmc-service-'+code
        sources[source] = dict(id=source,title=f'深圳地铁：{row["stationName"]}站动态查询（{code}）',url=info['pageURL'],accessedAt=date,sourcePublishedAt=None,
            license='深圳地铁官网公开查询资料；未获再分发授权。',note=f'通过页面使用的POST /zdxx、StieCode={code}查询。仅核验当前动态响应，不采用静态旧表；原始响应和SHA256保存在开发资料中。')
        for group, label in DAYS.items():
            for i, item in enumerate(raw.get(group, [])):
                name = item.get('suoshuluxian','').strip()
                line = 'l6b' if name == '6号线支线' else 'l'+name.replace('号线','')
                for suffix in ('','xia'):
                    original = {key:item.get(key+suffix) for key in ['xinshifangxiang','shoubanche','mobanche']}
                    record = dict(stationID=sid,lineID=line,sourceID=source,rawPath=f'raw/{code}.json',sha256=info['sha256'],fieldPath=f'{group}[{i}]/{suffix or "up"}',original=original,verifiedAt=date,method='dynamic_response_identity_schema_and_duplicate_checks')
                    direction = str(original['xinshifangxiang'] or '').strip()
                    try:
                        first, last = clock(original['shoubanche']), clock(original['mobanche'],last=True)
                        if not first and not last:
                            record['decision']='no_published_time'; audit.append(record); continue
                        if line not in stations[sid]['lineIDs']: raise ValueError('返回线路不属于本站；隔离且不修改地图归属')
                        if not direction or direction.removesuffix('站') == stations[sid]['name'].removesuffix('站'): raise ValueError('方向缺失或指向本站；未解决冲突')
                        if first and last and (last['dayOffset']*1440+int(last['clock'][:2])*60+int(last['clock'][3:])) < int(first['clock'][:2])*60+int(first['clock'][3:]): raise ValueError('末班早于首班，不能自动猜测日期')
                        t = dict(id=stable_id(sid,line,group,direction),lineID=line,direction=direction,serviceDays=label,validFrom=None,validThrough=None,first=first,last=last,lastDestination=None,serviceLabel=None,
                                 note='方向沿用来源行驶方向标签；未据此推定首末班实际终点。',sourceIDs=[source],updatedAt=date,verifiedAt=date)
                        if line in ('l2','l8'):
                            t['note'] += '2、8号线贯通运营；来源方向标签与实际终到站可能不同，实际终到站暂无已核实资料。'
                        candidates[sid].append(t); record.update(decision='candidate',candidateID=t['id'])
                    except ValueError as error:
                        record.update(decision='withheld',reason=str(error)); gaps[sid].append(dict(kind='timetable',lineID=line,reason=str(error),evidence=record))
                    audit.append(record)
        for i,e in enumerate(raw.get('outAndText',[])):
            desc = str(e.get('textt') or '').strip()
            if desc in ('无','--','暂无'):desc=None
            names=exit_names(e.get('outt',''))
            audit.append(dict(stationID=sid,sourceID=source,rawPath=f'raw/{code}.json',sha256=info['sha256'],fieldPath=f'outAndText[{i}]',original=e,decision='exit_candidate',normalizedNames=names,verifiedAt=date))
            for name in names:
                exits[sid].append(dict(id=stable_id(sid,'exit',name),name=name+'出口',description=desc,coordinate=None,sourceIDs=[source],updatedAt=date,verifiedAt=date))
    operator=json.loads((STORE/'operator/services.json').read_text())
    sources.update({s['id']:s for s in operator['sources']})
    for sid, data in operator['stations'].items():
        # Same direction's regular operator table overlaps weekday/rest values. Neither
        # source wins an unresolved discrepancy; short-turn records are distinct.
        for t in data['timetables']:
            conflicts=[]
            if t.get('serviceLabel') != '半程加班车':
                conflicts=[c for c in candidates[sid] if c['lineID']==t['lineID'] and c['direction']==t['direction'] and c['serviceDays'] in ('工作日','休息日') and signature(c)!=signature(t)]
            if conflicts:
                for c in conflicts:c['_conflict']=True
                t=dict(t,_conflict=True)
                gaps[sid].append(dict(kind='timetable',lineID=t['lineID'],reason='运营方原图与深铁动态常规时刻不同；双方冲突记录暂不展示',operator=t,dynamic=conflicts))
            candidates[sid].append(t)
        exits[sid].extend(data['exits'])
    out={}
    for sid,s in stations.items():
        grouped=defaultdict(list)
        for t in candidates[sid]:grouped[(t['lineID'],t['direction'],t['serviceDays'],t.get('serviceLabel'))].append(t)
        tables=[]
        for key,items in grouped.items():
            if any(t.get('_conflict') for t in items) or len({signature(t) for t in items}) > 1:
                gaps[sid].append(dict(kind='timetable',lineID=key[0],reason='同一方向及适用条件的来源冲突；未按请求先后覆盖',candidates=items));continue
            t=dict(items[0]);t['sourceIDs']=sorted({i for item in items for i in item['sourceIDs']});tables.append(t)
        egroup=defaultdict(list)
        for e in exits[sid]:
            names=exit_names(e['name'])
            if len(names)!=1:raise ValueError('运营方出口必须已拆分编号')
            egroup[names[0]].append(e)
        merged=[]
        for name,items in egroup.items():
            descs=defaultdict(set)
            for e in items:
                if e['description']:descs[e['description']].update(e['sourceIDs'])
            # Distinct descriptions are attributed independently; they are not silently
            # treated as interchangeable or a claim of exhaustive nearby landmarks.
            desc=None
            if len(descs)==1:desc=next(iter(descs))
            elif descs:
                desc='\n'.join(('港铁索引：' if all(i.startswith('mtr') for i in ids) else '深铁查询：')+d for d,ids in sorted(descs.items()))
            merged.append(dict(id=stable_id(sid,'exit',name),name=name+'出口',description=desc,coordinate=None,sourceIDs=sorted({i for e in items for i in e['sourceIDs']}),updatedAt=max(e['updatedAt'] for e in items),verifiedAt=max(e['verifiedAt'] for e in items)))
        for line in s['lineIDs']:
            if not any(t['lineID']==line for t in tables):gaps[sid].append(dict(kind='missingTimetable',lineID=line,reason='本站本线路暂无可展示的已核对时刻'))
        if not merged:gaps[sid].append(dict(kind='missingExit',reason='已查询来源未取得出口资料；不表示没有出口'))
        if any(e['description'] is None for e in merged):gaps[sid].append(dict(kind='exitDescription',reason='部分出口仅收录编号，道路及地标暂无资料'))
        conflict=any(g['kind']=='timetable' for g in gaps[sid])
        date=max(verified_dates)
        out[sid]=dict(timetables=sorted(tables,key=lambda t:(t['lineID'],t['direction'],t['serviceDays'],t.get('serviceLabel') or '')),exits=sorted(merged,key=lambda e:[(0,int(x)) if x.isdigit() else (1,x) for x in re.split(r'(\d+)',e['name'])]),serviceNotices=[],
            serviceReview=dict(timetableStatus='conflict' if conflict else ('partial' if tables else 'notCollected'),exitStatus='partial' if merged else 'notCollected',verifiedAt=date,
              timetableNote=('已收录来源当前公开时刻，未穷尽临时调整。' if tables else '暂无可展示的可靠时刻；查询缺失或冲突未解决。')+('部分来源冲突已隔离。' if conflict else '')+('2、8号线来源方向标签不代表每班实际终点。' if any(l in s['lineIDs'] for l in ['l2','l8']) else ''),
              exitNote='已收录出口编号及来源地点说明，不代表出口全部齐全；未确认实时开放状态，暂无精确出口坐标。' if merged else '暂无资料；来源缺失不表示出口不存在。',note=None))
    anomalies=json.loads((STORE/'anomalies.json').read_text())
    for anomaly in anomalies['anomalies']:
        if anomaly['status'] != 'unresolved': continue
        sid = anomaly['stationID']
        gaps[sid].append(dict(kind='directionUncertainty', reason='来源方向标签与贯通服务的实际终到站关系仍待核实；未推定实际终点。', sourceIDs=anomaly['sourceIDs'], evidence=anomaly['recommendation']))
        out[sid]['serviceReview']['timetableStatus'] = 'conflict'
        out[sid]['serviceReview']['timetableNote'] += '来源方向或实际终到站存在未解决疑点；仅保留可核对的来源原文，未指定实际终点。'
    for source in anomalies['sources']:
        if source['id'].startswith('jtys-2026'):
            sources[source['id']]=dict(id=source['id'],title='深圳市交通运输局：运营调整公告',url=source['url'],accessedAt=source['accessedAt'],sourcePublishedAt=source.get('sourcePublishedAt'),license='政府公开信息；未确认再分发授权。',note=source.get('note') or '按公告正文保留日期及原始时间限定，不自动推算本站首末班。')
    for notice in anomalies['datedNotices']:
        rules=notice.get('rules',[dict(stationID=notice['stationID'],text=notice['text'])] if 'stationID' in notice else [])
        for i,rule in enumerate(rules):
            targets=[rule['stationID']] if 'stationID' in rule else [sid for sid,s in stations.items() if set(s['lineIDs'])-set(notice.get('excludedLineIDs',[]))]
            for sid in targets:
                text = rule['text']
                if 'scope' in rule: text = rule['scope']+'：'+text
                out[sid]['serviceNotices'].append(dict(id='notice-'+notice['id']+'-'+str(i),text=text,serviceDates=rule.get('applicableDates') or notice.get('applicableDates') or [],validFrom=notice.get('validFrom'),validThrough=notice.get('validThrough'),sourceIDs=notice['sourceIDs'],verifiedAt=anomalies['auditDate']))
    for change in anomalies['documentedAdjustments']:
        sid=change['stationID']; out[sid]['serviceNotices'].append(dict(id=change['id'],text=f"6号线往{change['direction']}方向首班为{change['adjustedValue']['clock']}（公告未区分工作日、休息日）。",serviceDates=[],validFrom=change['validFrom'],validThrough=None,sourceIDs=change['sourceIDs'],verifiedAt=change['verifiedAt']))
        # Explicit later announcement conflicts are withheld, not applied to all service days.
        kept=[]
        for t in out[sid]['timetables']:
            if t['lineID']==change['lineID'] and t['direction']==change['direction'] and t['first']!=change['adjustedValue']:
                gaps[sid].append(dict(kind='timetable',lineID=t['lineID'],reason='动态首班与明确日期调整公告不同，保留公告参考并隔离冲突时刻',candidate=t));out[sid]['serviceReview']['timetableStatus']='conflict'
            else:kept.append(t)
        out[sid]['timetables']=kept
    # Reconcile availability after all conflict filters, including dated announcements.
    for sid, data in out.items():
        for line in stations[sid]['lineIDs']:
            if not any(t['lineID']==line for t in data['timetables']) and not any(g['kind']=='missingTimetable' and g.get('lineID')==line for g in gaps[sid]):
                gaps[sid].append(dict(kind='missingTimetable',lineID=line,reason='冲突过滤后本站本线路暂无可展示的确定时刻'))
        if not data['timetables']:
            data['serviceReview']['timetableNote']='暂无可展示的可靠时刻；查询缺失或冲突未解决。日期调整参考单独保留。'
        if data['serviceReview']['timetableStatus']=='conflict':
            reasons = list(dict.fromkeys(g['reason'] for g in gaps[sid] if g['kind'] in ('timetable','directionUncertainty')))
            data['serviceReview']['timetableNote'] += ' '+ '；'.join(reasons)
    result=dict(schemaVersion=2,verifiedAt=max(verified_dates),sources=list(sources.values()),stations=out)
    (STORE/'services.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    (STORE/'normalization-audit.json').write_text(json.dumps(dict(method='规则核验动态原文、重复及冲突检查；运营方图片另见人工核读记录；不是每条运营事实的独立交叉验证',records=audit,gaps=gaps),ensure_ascii=False,indent=2)+'\n')
    rows=[]
    for sid,s in stations.items():
        for line in s['lineIDs']:
            data=out[sid]; tt=[t for t in data['timetables'] if t['lineID']==line]
            relevant=[g for g in gaps[sid] if (not g.get('lineID') or g['lineID']==line) and (g['kind']!='directionUncertainty' or line in ('l2','l8'))]
            status='conflict' if any(g['kind'] in ('timetable','directionUncertainty') for g in relevant) else ('partial' if tt else 'notCollected')
            rows.append(dict(stationID=sid,stationName=s['name'],lineID=line,timetableCount=len(tt),timetableDirections='、'.join(sorted({t['direction'] for t in tt})),serviceConditions='；'.join(sorted({t['serviceDays'] for t in tt})),exitCount=len(data['exits']),timetableStatus=status,exitStatus=data['serviceReview']['exitStatus'],gaps='；'.join(dict.fromkeys(g['reason'] for g in relevant))))
    with (STORE/'coverage.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
    summary=dict(stations=len(out),memberships=len(rows),timetables=sum(len(s['timetables']) for s in out.values()),exits=sum(len(s['exits']) for s in out.values()),stationsWithTimetables=sum(bool(s['timetables']) for s in out.values()),stationsWithExits=sum(bool(s['exits']) for s in out.values()),conflictStations=sum(s['serviceReview']['timetableStatus']=='conflict' for s in out.values()),lines={l['id']:dict(memberships=sum(r['lineID']==l['id'] for r in rows),withTimetables=sum(r['lineID']==l['id'] and r['timetableCount']>0 for r in rows),timetables=sum(r['timetableCount'] for r in rows if r['lineID']==l['id'])) for l in city['lines']})
    for line,counts in summary['lines'].items():
        members=[r for r in rows if r['lineID']==line]
        counts.update(withExits=sum(r['exitCount']>0 for r in members),conflictMembers=sum(r['timetableStatus']=='conflict' for r in members),partialMembers=sum(r['timetableStatus']=='partial' for r in members),withoutTimetables=sum(r['timetableCount']==0 for r in members))
    (STORE/'coverage.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    report=['# 站点服务资料收录与缺口','',f'核对日期：{result["verifiedAt"]}。收录并非完整性承诺；所有站点出口按“已收录”展示。',f'{summary["stationsWithTimetables"]}/351站有时刻，{summary["stationsWithExits"]}/351站有出口。时刻{summary["timetables"]}项，出口{summary["exits"]}项，{summary["conflictStations"]}站存在隔离的时刻冲突。','','逐站、逐线路计数见 coverage.csv；原始值及隔离原因见 normalization-audit.json。','','|站点|线路|时刻条目|出口条目|缺口|','|---|---|---:|---:|---|']
    report.extend(f'|{r["stationName"]}|{r["lineID"]}|{r["timetableCount"]}|{r["exitCount"]}|{r["gaps"] or "已收录；未穷尽临时公告及全部出口"}|' for r in rows)
    (STORE/'GAPS.md').write_text('\n'.join(report)+'\n'); print(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__': normalize()
