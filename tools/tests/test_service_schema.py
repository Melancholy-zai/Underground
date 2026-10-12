"""Service schema tests derive v2 records from the permanent v1 sample."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import citypack


class ServiceSchemaTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / "tools/tests/fixtures/sample-city.json").read_text())
        self.station = self.data["stations"][0]
        self.timetable = {
            "id": "regular", "lineID": self.station["lineIDs"][0], "direction": "机场东",
            "serviceDays": "工作日", "validFrom": "2026-09-01", "validThrough": None,
            "first": {"clock": "06:20", "dayOffset": 0}, "last": {"clock": "23:00", "dayOffset": 0},
            "lastDestination": None, "note": None, "sourceIDs": ["sample"], "updatedAt": "2026-09-28",
        }
        self.exit = {"id": "exit-d", "name": "D出入口", "description": "道路资料", "coordinate": None,
                     "sourceIDs": ["sample"], "updatedAt": "2026-09-28"}
        self.station["timetables"] = [self.timetable]
        self.station["exits"] = [self.exit]

    def use_v2(self):
        self.data["schemaVersion"] = 2
        self.timetable["validFrom"] = None
        self.exit["description"] = None

    def notice(self):
        return {"id": "dated-reference", "text": "指定日期末班不早于次日01:00，以运营方安排为准。",
                "serviceDates": ["2026-09-30", "2026-10-01"], "sourceIDs": ["sample"], "verifiedAt": "2026-09-28"}

    def test_v1_without_new_fields_remains_valid(self):
        citypack.validate(self.data)
        for collection, key in [("timetables", "validFrom"), ("exits", "description")]:
            for absent in (False, True):
                data = copy.deepcopy(self.data)
                entry = data["stations"][0][collection][0]
                if absent:
                    del entry[key]
                else:
                    entry[key] = None
                with self.subTest(key=key, absent=absent), self.assertRaises(ValueError):
                    citypack.validate(data)

    def test_v2_accepts_unknown_metadata_and_keeps_special_service(self):
        self.use_v2()
        self.timetable["last"] = {"clock": "00:17", "dayOffset": 1}
        short = copy.deepcopy(self.timetable)
        short.update(id="half-route", first=None, last={"clock": "23:32", "dayOffset": 0},
                     serviceLabel="半程末班", lastDestination="龙华", verifiedAt="2026-09-28")
        self.station["timetables"].append(short)
        self.station["serviceReview"] = {"timetableStatus": "reviewed", "exitStatus": "partial",
                                         "verifiedAt": "2026-09-28", "timetableNote": "已核对", "exitNote": "缺道路资料"}
        self.data["sources"][0]["sourcePublishedAt"] = "2026-09-24"
        citypack.validate(self.data)
        self.assertEqual(short["lastDestination"], "龙华")
        self.assertEqual(citypack.check_time(self.timetable["last"]), 1457)
        del self.timetable["validFrom"]
        del self.exit["description"]
        citypack.validate(self.data)

    def test_v2_rejects_invalid_timetable_dates_sources_and_empty_times(self):
        self.use_v2()
        changes = [
            {"first": None, "last": None}, {"first": {}, "last": self.timetable["last"]},
            {"validFrom": "2026-02-30"}, {"validFrom": "2026-9-01"},
            {"validFrom": "2026-09-02", "validThrough": "2026-09-01"},
            {"verifiedAt": "2026-09-31"}, {"updatedAt": ""}, {"validThrough": "unknown"},
            {"sourceIDs": ["missing"]}, {"sourceIDs": []}, {"lineID": "l5"}, {"serviceLabel": " "},
            {"last": {"clock": "00:17", "dayOffset": 0}}, {"first": {"clock": "--", "dayOffset": 0}},
        ]
        for change in changes:
            data = copy.deepcopy(self.data)
            data["stations"][0]["timetables"][0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                citypack.validate(data)

    def test_v2_rejects_invalid_exit_fields(self):
        self.use_v2()
        for change in [{"name": " "}, {"description": ""}, {"description": 42}, {"verifiedAt": "2026-02-29"},
                       {"updatedAt": "today"}, {"sourceIDs": ["missing"]}, {"sourceIDs": []}]:
            data = copy.deepcopy(self.data)
            data["stations"][0]["exits"][0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                citypack.validate(data)

    def test_source_dates_are_strict(self):
        self.use_v2()
        for key in ("accessedAt", "sourcePublishedAt"):
            data = copy.deepcopy(self.data)
            data["sources"][0][key] = "2026-02-30"
            with self.subTest(key=key), self.assertRaises(ValueError):
                citypack.validate(data)

    def test_review_requires_known_statuses_and_correct_shapes(self):
        self.use_v2()
        for review in [{"timetableStatus": "complete", "exitStatus": "partial"},
                       {"timetableStatus": "reviewed"},
                       {"timetableStatus": "reviewed", "exitStatus": "partial", "verifiedAt": "2026-04-31"},
                       {"timetableStatus": "reviewed", "exitStatus": "partial", "exitNote": []}, []]:
            self.station["serviceReview"] = review
            with self.subTest(review=review), self.assertRaises(ValueError):
                citypack.validate(self.data)

    def test_notices_preserve_non_exact_text_and_explicit_dates(self):
        self.use_v2()
        notice = self.notice()
        self.station["serviceNotices"] = [notice]
        citypack.validate(self.data)
        self.assertIn("不早于", notice["text"])
        self.assertEqual(len(self.station["timetables"]), 1)
        notice.update(serviceDates=[], validFrom="2026-09-30", validThrough="2026-10-07")
        citypack.validate(self.data)

    def test_notices_reject_invalid_or_missing_applicability(self):
        self.use_v2()
        changes = [{"serviceDates": []}, {"serviceDates": ["2026-09-31"]},
                   {"serviceDates": ["2026-10-01", "2026-10-01"]},
                   {"serviceDates": ["2026-10-01", "2026-09-30"]},
                   {"validFrom": "2026-10-07", "validThrough": "2026-10-01"},
                   {"verifiedAt": "unknown"}, {"sourceIDs": []}, {"sourceIDs": ["missing"]},
                   {"text": " "}, {"id": ""}]
        for change in changes:
            notice = self.notice()
            notice.update(change)
            self.station["serviceNotices"] = [notice]
            with self.subTest(change=change), self.assertRaises(ValueError):
                citypack.validate(self.data)
        self.station["serviceNotices"] = [self.notice(), self.notice()]
        with self.assertRaises(ValueError):
            citypack.validate(self.data)

    def test_duplicate_service_ids_rejected(self):
        self.use_v2()
        for collection in ("timetables", "exits"):
            data = copy.deepcopy(self.data)
            records = data["stations"][0][collection]
            records.append(copy.deepcopy(records[0]))
            with self.subTest(collection=collection), self.assertRaises(ValueError):
                citypack.validate(data)

    def test_build_verify_versions_hashes_and_manifest_match(self):
        for version in (1, 2):
            self.data["schemaVersion"] = version
            with self.subTest(version=version), tempfile.TemporaryDirectory() as folder:
                folder = Path(folder)
                citypack.build(self.data, folder)
                manifest_path = folder / "manifest.json"
                original = json.loads(manifest_path.read_text())
                self.assertEqual(original["schemaVersion"], version)
                citypack.verify_bundle(folder)
                for key, value in [("schemaVersion", 3), ("schemaVersion", 3-version),
                                   ("schemaVersion", True), ("cityID", "wrong"), ("version", "wrong")]:
                    manifest = copy.deepcopy(original)
                    manifest[key] = value
                    manifest_path.write_text(json.dumps(manifest))
                    with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                        citypack.verify_bundle(folder)
                manifest_path.write_text(json.dumps(original))
                for name in ("city.json", "map.svg"):
                    path = folder / name
                    contents = path.read_bytes()
                    path.write_bytes(contents + b" ")
                    with self.subTest(file=name), self.assertRaises(ValueError):
                        citypack.verify_bundle(folder)
                    path.write_bytes(contents)
                citypack.verify_bundle(folder)

    def test_unsupported_city_versions_rejected(self):
        for version in (0, 3, True, "2"):
            self.data["schemaVersion"] = version
            with self.subTest(version=version), self.assertRaises(ValueError):
                citypack.validate(self.data)


if __name__ == "__main__":
    unittest.main()
