import copy
import importlib.util
import json
import sys
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))


class CityPackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("citypack", ROOT / "tools/citypack.py")
        cls.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.tool)

    def setUp(self):
        self.data = json.loads((ROOT / "tools/tests/fixtures/sample-city.json").read_text())

    def test_sample_valid_but_not_production(self):
        self.tool.validate(self.data)
        with self.assertRaises(ValueError):
            self.tool.validate(self.data, production=True)

    def test_non_sample_cannot_bypass_production_review(self):
        self.data["isSample"] = False
        with self.assertRaises(ValueError):
            self.tool.validate(self.data)

    def test_required_fields_match_swift_decoding(self):
        for collection, field in [("stations", "aliases"), ("lines", "shortName"), ("districts", "name")]:
            data = copy.deepcopy(self.data)
            del data[collection][0][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.tool.validate(data)
        del self.data["disclaimer"]
        with self.assertRaises(ValueError):
            self.tool.validate(self.data)

    def test_wrong_field_type_rejected(self):
        self.data["stations"][0]["aliases"] = [42]
        with self.assertRaises(ValueError):
            self.tool.validate(self.data)

    def test_duplicate_station_rejected(self):
        self.data["stations"].append(copy.deepcopy(self.data["stations"][0]))
        with self.assertRaises(ValueError):
            self.tool.validate(self.data)

    def test_unknown_station_reference_rejected(self):
        self.data["lines"][0]["stationIDs"].append("missing")
        with self.assertRaises(ValueError):
            self.tool.validate(self.data)

    def test_wrong_coordinate_system_rejected(self):
        self.data["stations"][0]["coordinate"] = {"latitude": 22.5, "longitude": 114, "system": "gcj02"}
        with self.assertRaises(ValueError):
            self.tool.validate(self.data)

    def test_mismatched_membership_rejected(self):
        self.data["stations"][0]["lineIDs"] = []
        with self.assertRaises(ValueError):
            self.tool.validate(self.data)

    def test_svg_has_one_object_per_station(self):
        with tempfile.TemporaryDirectory() as folder:
            self.tool.build(self.data, Path(folder))
            svg = ET.parse(Path(folder) / "map.svg")
            ids = [node.attrib["data-station"] for node in svg.iter() if "data-station" in node.attrib]
            self.assertEqual(set(ids), {s["id"] for s in self.data["stations"]})
            self.assertEqual(len(ids), len(set(ids)))
            self.tool.verify_bundle(Path(folder))
            with (Path(folder) / "city.json").open("a") as file:
                file.write(" ")
            with self.assertRaises(ValueError):
                self.tool.verify_bundle(Path(folder))

    def test_svg_text_is_escaped(self):
        self.data["stations"][0]["name"] = "站<&名"
        svg = self.tool.render_svg(self.data)
        self.assertIn("站&lt;&amp;名", svg)
        ET.fromstring(svg)

    def test_invalid_clock_rejected(self):
        for clock in ["24:00", "6:00", "06:99"]:
            with self.assertRaises(ValueError):
                self.tool.check_time({"clock": clock, "dayOffset": 0})
        self.tool.check_time({"clock": "00:13", "dayOffset": 1})


if __name__ == "__main__":
    unittest.main()
