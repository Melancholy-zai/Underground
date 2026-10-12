import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class FullNetworkTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'data/shenzhen/source.json').read_text())
        self.official = json.loads((ROOT / 'data/shenzhen/references/official-fare-stations.json').read_text())
        self.names = {s['id']: s['name'] for s in self.data['stations']}

    def test_every_official_line_and_station_in_order(self):
        expected = {l['number']: l['stations'] for l in self.official['lines']}
        actual = {l['shortName']: [self.names[s] for s in l['stationIDs']] for l in self.data['lines']}
        self.assertEqual(actual, expected)
        self.assertEqual(len(self.data['stations']), 351)
        self.assertEqual(sum(len(l['stationIDs']) for l in self.data['lines']), 432)
        self.assertEqual(sum(len(s['lineIDs']) > 1 for s in self.data['stations']), 68)

    def test_through_service_is_connected_without_fake_interchange(self):
        c = self.data['throughServices'][0]
        self.assertEqual([self.names[c['fromStationID']], self.names[c['toStationID']]], ['莲塘', '梧桐山南'])
        self.assertEqual(c['lineIDs'], ['l2', 'l8'])
        self.assertEqual(next(s for s in self.data['stations'] if s['name']=='莲塘')['lineIDs'], ['l2'])
        import re
        paths={l['id']: l['diagramPath'] for l in self.data['lines']}
        end=re.findall(r'[-+]?[0-9]*[.]?[0-9]+',paths['l2'])[-2:]
        start=re.findall(r'[-+]?[0-9]*[.]?[0-9]+',paths['l8'])[:2]
        self.assertEqual(end,start, '2/8 line paths must meet without a physical gap')

    def test_generated_svg_has_independent_clickable_legends(self):
        import sys, xml.etree.ElementTree as ET
        sys.path.insert(0,str(ROOT/'tools'))
        from citypack import render_svg
        root=ET.fromstring(render_svg(self.data))
        legends=[n for n in root.iter() if 'data-legend-line' in n.attrib]
        self.assertEqual({n.get('data-legend-line') for n in legends}, {l['id'] for l in self.data['lines']})
        self.assertEqual(len(legends),17)
        for n in legends:
            self.assertEqual(n.get('role'),'button')
            self.assertEqual(n.get('aria-pressed'),'false')
            self.assertTrue(any(c.get('class')=='legend-hit' for c in n))
        self.assertNotIn('data-highlight-lines',ET.tostring(root).decode())
        # Decorative hidden groups must not hide interactive descendants.
        for n in root.iter():
            if n.get('aria-hidden')=='true':
                self.assertFalse(any(c.get('data-legend-line') for c in n.iter()))

    def test_schematic_complete_and_not_geographic(self):
        positions = {(s['diagram']['x'], s['diagram']['y']) for s in self.data['stations']}
        self.assertEqual(len(positions),351)
        self.assertTrue(all(l.get('diagramPath') for l in self.data['lines']))
        self.assertFalse(any('西丽高铁' in s['name'] or s['name'] in ['潮汐公园','歌剧院'] for s in self.data['stations']))
        self.assertTrue(all(s['coordinate'] is None or s['coordinateSourceIDs'] for s in self.data['stations']))
        self.assertFalse(self.data['isSample'])
        self.assertIsNone(self.data.get('coverageReview'))

    def test_network_status_does_not_skip_production_review(self):
        import importlib.util
        spec=importlib.util.spec_from_file_location('citypack',ROOT/'tools/citypack.py')
        tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)
        tool.validate(self.data)
        with self.assertRaises(ValueError): tool.validate(self.data,production=True)
        self.data['networkReview']['stationCount']=17
        with self.assertRaises(ValueError): tool.validate(self.data)

    def test_svg_paths_reject_embedded_markup(self):
        import importlib.util
        spec=importlib.util.spec_from_file_location('citypack',ROOT/'tools/citypack.py')
        tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)
        self.data['lines'][0]['diagramPath']='M 0 0"><script>bad</script>'
        with self.assertRaises(ValueError): tool.validate(self.data)

    def test_invalid_geometry_and_through_field_type_fail_before_packaging(self):
        import copy, importlib.util
        spec=importlib.util.spec_from_file_location('citypack',ROOT/'tools/citypack.py')
        tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)
        for path in ['M', 'M 0 0', 'M 0 0 L 1', 'M 0 0 C 1 2', 'M 0 0 Z 1 2']:
            bad=copy.deepcopy(self.data);bad['lines'][0]['diagramPath']=path
            with self.subTest(path=path), self.assertRaises(ValueError): tool.validate(bad)
        self.data['throughServices'][0]['note']=123
        with self.assertRaises(ValueError): tool.validate(self.data)

if __name__ == '__main__': unittest.main()
