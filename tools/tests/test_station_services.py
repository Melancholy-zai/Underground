import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from normalize_station_services import clock, exit_names, stable_id
from collect_shenzhen import generate

ROOT = Path(__file__).resolve().parents[2]

class StationServiceImportTests(unittest.TestCase):
    def test_non_times_are_never_midnight(self):
        for v in ('--', '---', '', None): self.assertIsNone(clock(v))
        for v in ('约23:00', '不早于01:00', '开站6:30'):
            with self.assertRaises(ValueError): clock(v, last=True)
        self.assertEqual(clock('00:17', last=True), {'clock':'00:17','dayOffset':1})
        self.assertEqual(clock('24:12', last=True), {'clock':'00:12','dayOffset':1})

    def test_exit_group_numbers_keep_source_scope(self):
        self.assertEqual(exit_names('2-6号出入口'), ['2','3','4','5','6'])
        self.assertEqual(exit_names('E1/E2出入口'), ['E1','E2'])
        self.assertEqual(exit_names('  B出入口（临时关闭）'), ['B'])
        self.assertEqual(exit_names('8、9a、9b出入口'), ['8','9A','9B'])

    def test_generation_keeps_reviewed_service_input_and_map_memberships(self):
        first, second = generate(), generate()
        self.assertEqual(first, second)
        services=json.loads((ROOT/'data/shenzhen/references/station-services/services.json').read_text())
        self.assertEqual(first['schemaVersion'], 2)
        self.assertEqual(len(first['stations']),351)
        for s in first['stations']:
            for key in ['exits','timetables','serviceReview','serviceNotices']:
                self.assertEqual(s[key],services['stations'][s['id']][key])
        byname={s['name']:s for s in first['stations']}
        self.assertEqual(byname['莲塘']['lineIDs'], ['l2'])
        self.assertTrue(all(t['lineID']=='l2' and t['direction']!='莲塘' for t in byname['莲塘']['timetables']))
        self.assertTrue(all(t['lastDestination'] is None for t in byname['溪涌']['timetables']))

    def test_real_dynamic_and_operator_anomalies(self):
        stations={s['name']:s for s in generate()['stations']}
        luohu=stations['罗湖']
        work=next(t for t in luohu['timetables'] if t['lineID']=='l1' and t['serviceDays']=='工作日')
        self.assertEqual(work['first']['clock'],'06:20')
        self.assertIsNone(work['validFrom'])
        self.assertIsNone(next(e for e in luohu['exits'] if e['name']=='D出口')['description'])
        qianhai=stations['前海湾']
        self.assertEqual({t['lineID'] for t in qianhai['timetables']},{'l1','l5','l11'})
        self.assertTrue(any(t['last']=={'clock':'00:17','dayOffset':1} for t in qianhai['timetables']))
        lake=stations['观澜湖']
        short=next(t for t in lake['timetables'] if t['serviceLabel']=='半程加班车')
        self.assertEqual(short['lastDestination'],'龙华')
        self.assertEqual(short['last']['clock'],'23:32')
        self.assertTrue(any(t['serviceLabel']=='全程' and t['last']['clock']=='23:02' for t in lake['timetables']))
        self.assertTrue(any('玉蓢社区健康服务中心' in (e['description'] or '') for e in stations['李松蓢']['exits']))
        airport=stations['机场']['serviceNotices']
        self.assertTrue(any('不早于次日01:00' in n['text'] for n in airport))
        self.assertTrue(all('2026-09-28' not in n['serviceDates'] for n in airport))

if __name__=='__main__':unittest.main()
