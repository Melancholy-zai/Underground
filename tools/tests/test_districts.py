"""Regression: collecting a complete network must not discard district backgrounds."""
import sys
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from collect_shenzhen import generate
from citypack import render_svg, validate, polygon_contains


class DistrictTests(unittest.TestCase):
    def test_district_neighbors_match_the_official_area_descriptions(self):
        districts = {d['id']: d['polygon'] for d in generate()['districts']}

        def shares_border(first, second):
            # A single meeting point is not a shared district boundary. Allow
            # the same straight border to be split into different segments.
            for a, b in zip(first, first[1:] + first[:1]):
                for c, d in zip(second, second[1:] + second[:1]):
                    dx, dy = b['x'] - a['x'], b['y'] - a['y']
                    cross = lambda p: dx * (p['y'] - a['y']) - dy * (p['x'] - a['x'])
                    if abs(cross(c)) > 1e-6 or abs(cross(d)) > 1e-6:
                        continue
                    axis = 'x' if abs(dx) >= abs(dy) else 'y'
                    lower = max(min(a[axis], b[axis]), min(c[axis], d[axis]))
                    upper = min(max(a[axis], b[axis]), max(c[axis], d[axis]))
                    if upper - lower > 1e-6:
                        return True
            return False

        self.assertTrue(shares_border(districts['longhua'], districts['luohu']),
                        '龙华南接罗湖，示意图也应保留共界')
        self.assertFalse(shares_border(districts['futian'], districts['longgang']),
                         '福田北接龙华，不能因压缩示意图制造福田—龙岗共界')
        validate(generate())

    def test_regeneration_keeps_colored_districts_below_the_network(self):
        data = generate()
        root = ET.fromstring(render_svg(data))
        groups = [node for node in root if 'data-district' in node.attrib]
        self.assertEqual({node.attrib['data-district'] for node in groups},
                         {'baoan', 'nanshan', 'futian', 'luohu', 'yantian',
                          'longhua', 'longgang', 'guangming', 'pingshan', 'dapeng'})
        first_line = next(i for i, node in enumerate(root) if 'data-line' in node.attrib)
        for group in groups:
            self.assertLess(list(root).index(group), first_line)
            polygon = group.find('{http://www.w3.org/2000/svg}polygon')
            self.assertIsNotNone(polygon)
            self.assertNotIn(polygon.attrib.get('fill'), (None, 'none', '#ffffff'))
            self.assertTrue(group.find('{http://www.w3.org/2000/svg}text').text)

    def test_known_stations_keep_the_correct_district_at_transitions(self):
        stations = {s['name']: s for s in generate()['stations']}
        for name, district in {'新安': 'baoan', '前海湾': 'nanshan',
                               '侨城北': 'nanshan', '深康': 'futian',
                               '梧桐山南': 'luohu', '沙头角': 'yantian',
                               '小梅沙': 'yantian', '溪涌': 'dapeng',
                               '百鸽笼': 'longgang', '布心': 'luohu',
                               '长岭陂': 'nanshan', '深圳北站': 'longhua',
                               '百旺': 'nanshan', '应人石': 'baoan',
                               '上屋': 'baoan', '红坳公园': 'guangming',
                               '宝龙': 'longgang', '锦龙': 'pingshan'}.items():
            with self.subTest(station=name):
                self.assertEqual(stations[name]['districtIDs'], [district])

    def test_unresolved_stations_stay_unassigned_without_map_warnings(self):
        import math
        data = generate()
        svg = render_svg(data)
        root = ET.fromstring(svg)
        self.assertNotIn('district-pending', svg)
        self.assertNotIn('待核实', svg)
        unresolved = [s for s in data['stations'] if not s['districtIDs']]
        self.assertEqual(len(unresolved), 6)
        for station in unresolved:
            self.assertTrue(station['districtNote'])
            node = next(n for n in root if n.get('data-station') == station['id'])
            labels = [n.text for n in node if n.tag.endswith('text')]
            self.assertEqual(labels, [station['name']])
            # Normal district boundaries pass beneath the marker, so removing
            # warning decorations does not give it a definite district color.
            x, y = station['diagram']['x'], station['diagram']['y']
            def distance(a, b):
                dx, dy = b['x']-a['x'], b['y']-a['y']
                t = max(0, min(1, ((x-a['x'])*dx+(y-a['y'])*dy)/(dx*dx+dy*dy)))
                return math.hypot(x-a['x']-t*dx, y-a['y']-t*dy)
            adjacent = [d for d in data['districts'] if min(distance(a,b) for a,b in
                        zip(d['polygon'], d['polygon'][1:]+d['polygon'][:1])) < 1]
            self.assertGreaterEqual(len(adjacent), 2, station['name'])

    def test_background_cannot_put_a_station_in_another_district(self):
        data = generate()
        district = next(d for d in data['districts'] if d['id'] == 'nanshan')
        district['polygon'] = [{'x': 0, 'y': 0}, {'x': 10, 'y': 0}, {'x': 0, 'y': 10}]
        with self.assertRaisesRegex(ValueError, '区名|底色'):
            validate(data)

    def test_shared_borders_do_not_create_spurious_district_coverage(self):
        districts = generate()['districts']
        for point, expected in [({'x': 1570, 'y': 1930}, {'nanshan', 'futian'}),
                                ({'x': 4200, 'y': 1954}, {'dapeng'})]:
            with self.subTest(point=point):
                translated = {'x': point['x'] + 600, 'y': point['y'] + 820}
                covered = {d['id'] for d in districts if polygon_contains(translated, d['polygon'])}
                self.assertEqual(covered, expected)


if __name__ == '__main__':
    unittest.main()
