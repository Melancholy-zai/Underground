"""Navigation data must survive city-pack rebuilds with explicit provenance/datum."""
import copy
import importlib.util
import json
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class NavigationDataTests(unittest.TestCase):
    def test_all_operating_stations_have_unique_amap_locations(self):
        data = module('collect_shenzhen').generate()
        locations = [s['amapLocation'] for s in data['stations']]
        self.assertEqual(len(locations), 351)
        self.assertEqual(len({p['poiID'] for p in locations}), 351)
        self.assertTrue(all(p['system'] == 'gcj02' and p['sourceIDs'] for p in locations))
        self.assertEqual(data, json.loads((ROOT / 'data/shenzhen/source.json').read_text()))

    def test_amap_position_validation(self):
        data = module('collect_shenzhen').generate()
        tool = module('citypack')
        tool.validate(data)
        for field, value in [('system', 'wgs84'), ('latitude', 200), ('longitude', None),
                             ('poiID', ''), ('sourceIDs', []), ('sourceIDs', ['unknown']), ('updatedAt', '')]:
            broken = copy.deepcopy(data)
            broken['stations'][0]['amapLocation'][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                tool.validate(broken)
