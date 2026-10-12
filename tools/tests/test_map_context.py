import copy
import json
import sys
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from collect_shenzhen import generate
from citypack import validate, render_svg, polygon_contains

class MapContextTests(unittest.TestCase):
    def test_context_contains_independent_boundaries_and_sources(self):
        d=generate(); c=d.get('mapContext')
        self.assertIsNotNone(c)
        self.assertEqual({b['kind'] for b in c['boundaries']},{'city','region','coast'})
        self.assertTrue(all(b['sourceIDs'] and len(b['sides'])==2 for b in c['boundaries']))
        self.assertGreater(d['map']['width']/d['map']['height'],1.0)
        self.assertEqual(c['reviewedAt'],'2026-09-28')
        self.assertEqual(d['dataAsOf'],'2026-06-28')

    def test_svg_is_self_contained_and_legends_are_not_interactive_objects(self):
        d=generate(); svg=render_svg(d); root=ET.fromstring(svg)
        for t in ['东莞市','惠州市','香港特别行政区','深汕特别合作区','海岸线','站外换乘','不代表真实距离和精确地理边界']:
            self.assertTrue(t in svg,t)
        self.assertEqual(len([n for n in root.iter() if 'data-line' in n.attrib]),17)
        self.assertEqual(len([n for n in root.iter() if 'data-station' in n.attrib]),351)
        self.assertEqual({n.attrib['data-map-focus'] for n in root.iter() if 'data-map-focus' in n.attrib},{'surroundings','legend-lines','legend-symbols'})
        self.assertEqual(len([n for n in root.iter() if 'data-boundary' in n.attrib]),5)
        self.assertNotIn('行政分区底色', svg)
        self.assertNotIn('2026-06-28', svg)
        self.assertNotIn(d['version'], svg)
        for inset in d['mapContext']['insets']:
            self.assertLess(inset['frame']['y']+inset['frame']['height'], d['mapContext']['networkFrame']['y'])
        for focus in d['mapContext']['focusAreas']:
            if focus['id'].startswith('legend-'):
                self.assertGreater(focus['frame']['y'], d['mapContext']['networkFrame']['y']+d['mapContext']['networkFrame']['height'])


    def test_bad_boundary_kind_and_source_are_rejected(self):
        for field,value in [('kind','district'),('sourceIDs',['missing']),('sides',['深圳']),('points',[])]:
            d=generate()
            self.assertIn('mapContext',d)
            d['mapContext']['boundaries'][0][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):validate(d)

    def test_translation_preserves_network_and_navigation(self):
        d=generate(); layout=json.loads((ROOT/'data/shenzhen/references/schematic-layout.json').read_text())
        for s in d['stations']:
            original=layout['stations'][s['name']]['diagram']
            self.assertAlmostEqual(s['diagram']['x'],original['x']+600)
            self.assertAlmostEqual(s['diagram']['y'],original['y']+820)
        taoyuan=next(s for s in d['stations'] if s['id']=='taoyuan')
        self.assertEqual(taoyuan['amapLocation']['longitude'],113.924781)

    def test_district_mosaic_has_no_sampled_gaps_or_overlaps(self):
        d=generate()
        outer=[(80,40),(4350,40),(4350,3100),(3750,3100),(3440,2910),
               (3060,3150),(2374,3150),(2374,3300),(1420,3520),(80,3520)]
        envelope=[{'x':x+600,'y':y+820} for x,y in outer]
        for x in range(80,4350,55):
            for y in range(40,3520,55):
                point={'x':x+600+.123,'y':y+820+.321}
                count=sum(polygon_contains(point,a['polygon']) for a in d['districts'])
                self.assertEqual(count, int(polygon_contains(point,envelope)), str(point))

if __name__=='__main__':unittest.main()
