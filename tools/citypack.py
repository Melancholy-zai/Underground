#!/usr/bin/env python3
from map_context import validate_context, render_background, render_boundaries, render_foreground
"""Offline city package builder. Standard library only; no scraping or network calls."""
import argparse
import hashlib
import html
import json
import math
from pathlib import Path
import re
import sys
from datetime import date
import xml.etree.ElementTree as ET

ID = re.compile(r"^[a-z][a-z0-9_-]*$")
COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_date(value, optional=False):
    if optional and value is None:
        return
    require(isinstance(value, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", value), "日期必须为 YYYY-MM-DD")
    date.fromisoformat(value)


def check_time(value):
    require(isinstance(value, dict), "时间必须为对象")
    require(isinstance(value.get("clock"), str) and re.fullmatch(r"([01][0-9]|2[0-3]):[0-5][0-9]", value["clock"]), "时间必须为 00:00 至 23:59")
    require(type(value.get("dayOffset")) is int and value["dayOffset"] in (0, 1), "dayOffset 必须为 0 或 1")
    hours, minutes = map(int, value["clock"].split(":"))
    return value["dayOffset"] * 1440 + hours * 60 + minutes


def coordinate(value):
    if value is None:
        return
    require(value.get("system") == "wgs84", "第一版只接收 WGS84；禁止把 GCJ02/BD09 直接改名")
    for name, limit in [("latitude", 90), ("longitude", 180)]:
        number = value.get(name)
        require(type(number) in (int, float) and math.isfinite(number) and abs(number) <= limit, "经纬度越界")


def index(values, name):
    result = {}
    for item in values:
        key = item.get("id", "")
        require(ID.fullmatch(key) and key not in result, f"{name} 编号无效或重复：{key}")
        result[key] = item
    return result


def polygon_contains(point, polygon):
    """Schematic coordinates only; include points on a shared boundary."""
    x, y = point['x'], point['y']
    inside = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        ax, ay, bx, by = a['x'], a['y'], b['x'], b['y']
        cross = (x-ax)*(by-ay) - (y-ay)*(bx-ax)
        if abs(cross) < 1e-6 and min(ax, bx) <= x <= max(ax, bx) and min(ay, by) <= y <= max(ay, by):
            return True
        if (ay > y) != (by > y) and x < (bx-ax)*(y-ay)/(by-ay) + ax:
            inside = not inside
    return inside


def check_shape(data):
    """Validate every Codable field before cross-reference checks or SVG generation."""
    def fields(item, specification, path):
        require(isinstance(item, dict), f"{path} 必须为对象")
        for key, kind in specification.items():
            require(key in item, f"缺少字段 {path}.{key}")
            value = item[key]
            optional = kind.endswith("?")
            kind = kind.rstrip("?")
            if value is None and optional:
                continue
            if kind == "strings":
                valid = type(value) is list and all(type(v) is str for v in value)
            elif kind == "number":
                valid = type(value) in (int, float) and math.isfinite(value)
            else:
                valid = type(value) is {"string": str, "int": int, "bool": bool, "array": list, "object": dict}[kind]
            require(valid, f"字段类型错误 {path}.{key}")
    def optional_fields(item, specification, path):
        fields(item, {key: kind for key, kind in specification.items() if key in item}, path)

    fields(data, dict(schemaVersion="int", cityID="string", cityName="string", version="string", dataAsOf="string?",
                      generatedAt="string", isSample="bool", coverageNote="string", disclaimer="string", map="object",
                      stations="array", lines="array", districts="array", sources="array"), "city")
    require(data["schemaVersion"] in (1, 2), "不支持的 schemaVersion")
    version = data["schemaVersion"]
    fields(data["map"], dict(width="number", height="number"), "map")
    for item in data["stations"]:
        fields(item, dict(id="string", name="string", aliases="strings", districtIDs="strings", districtNote="string?",
                          lineIDs="strings", diagram="object", labelOffset="object", coordinate="object?",
                          coordinateSourceIDs="strings", exits="array", timetables="array", sourceIDs="strings",
                          updatedAt="string?", note="string?"), "station")
        for key in ("diagram", "labelOffset"):
            fields(item[key], dict(x="number", y="number"), key)
        for entry in item["exits"]:
            fields(entry, dict(id="string", name="string", coordinate="object?", sourceIDs="strings", updatedAt="string"), "exit")
            (fields if version == 1 else optional_fields)(entry, dict(description="string" if version == 1 else "string?"), "exit")
            optional_fields(entry, dict(verifiedAt="string?"), "exit")
        for entry in item["timetables"]:
            fields(entry, dict(id="string", lineID="string", direction="string", serviceDays="string",
                               validThrough="string?", first="object?", last="object?", lastDestination="string?",
                               note="string?", sourceIDs="strings", updatedAt="string"), "timetable")
            (fields if version == 1 else optional_fields)(entry, dict(validFrom="string" if version == 1 else "string?"), "timetable")
            optional_fields(entry, dict(serviceLabel="string?", verifiedAt="string?"), "timetable")
        optional_fields(item, dict(serviceReview="object?", serviceNotices="array?"), "station")
        review = item.get("serviceReview")
        if review is not None:
            fields(review, dict(timetableStatus="string", exitStatus="string"), "serviceReview")
            optional_fields(review, dict(note="string?", verifiedAt="string?", timetableNote="string?", exitNote="string?"), "serviceReview")
        for notice in item.get("serviceNotices") or []:
            fields(notice, dict(id="string", text="string", serviceDates="strings", sourceIDs="strings", verifiedAt="string"), "serviceNotice")
            optional_fields(notice, dict(validFrom="string?", validThrough="string?"), "serviceNotice")
    for item in data["lines"]:
        fields(item, dict(id="string", name="string", shortName="string", color="string", stationIDs="strings", termini="strings", sourceIDs="strings", coverageNote="string?"), "line")
    for item in data["districts"]:
        fields(item, dict(id="string", name="string", color="string", polygon="array", label="object", note="string?"), "district")
        for point in item["polygon"] + [item["label"]]:
            fields(point, dict(x="number", y="number"), "point")
    for item in data["sources"]:
        fields(item, dict(id="string", title="string", url="string?", accessedAt="string", license="string", note="string"), "source")
        optional_fields(item, dict(sourcePublishedAt="string?"), "source")

    # Optional geometry/status additions must remain compatible with Swift Codable.
    if data.get("networkReview") is not None:
        fields(data["networkReview"], dict(reviewedAt="string", sourceIDs="strings", lineCount="int", stationCount="int", membershipCount="int"), "networkReview")
    if data.get("throughServices") is not None:
        fields(data, dict(throughServices="array"), "city")
        for service in data["throughServices"]:
            fields(service, dict(fromStationID="string", toStationID="string", lineIDs="strings", note="string"), "throughService")
    for item in data["lines"]:
        if item.get("badgePosition") is not None:
            fields(item["badgePosition"], dict(x="number", y="number"), "badgePosition")


def check_svg_path(value):
    require(isinstance(value, str) and re.fullmatch(r"[MLCZmlcz0-9., +\-]+", value), "SVG 路径只能包含受支持的几何命令")
    commands = re.findall(r"([MLCZmlcz])([^MLCZmlcz]*)", value)
    require(commands and commands[0][0].upper() == "M" and value.lstrip()[0].upper() == "M", "路径必须由 M 开始")
    drawing = False
    for command, raw in commands:
        # Our generator writes explicit commands; reject incomplete argument groups.
        parts = raw.replace(',', ' ').split()
        try:
            numbers = [float(p) for p in parts]
        except ValueError:
            raise ValueError("SVG 路径数值无效") from None
        require(all(math.isfinite(n) for n in numbers), "SVG 路径数值无效")
        command = command.upper()
        arity = {"M": 2, "L": 2, "C": 6, "Z": 0}[command]
        require((len(numbers) == 0) if arity == 0 else (len(numbers) >= arity and len(numbers) % arity == 0), "SVG 命令参数数量不正确")
        drawing |= command in ("L", "C")
    require(drawing, "SVG 路径缺少可绘制线段")


def validate(data, production=False):
    check_shape(data)
    validate_context(data)
    require(data["schemaVersion"] in (1, 2), "不支持的 schemaVersion")
    require(ID.fullmatch(data["cityID"]), "城市编号无效")
    require(data["version"] and data["cityName"] and data["coverageNote"], "缺少版本或覆盖说明")
    require(type(data["isSample"]) is bool, "isSample 必须为布尔值")
    check_date(data["generatedAt"])
    check_date(data["dataAsOf"], optional=True)
    width, height = data["map"]["width"], data["map"]["height"]
    require(0 < width <= 20000 and 0 < height <= 20000, "示意图尺寸越界")
    stations, lines = index(data["stations"], "站点"), index(data["lines"], "线路")
    districts, sources = index(data["districts"], "行政区"), index(data["sources"], "来源")
    require(stations and lines and sources, "资料包不能为空")

    def refs(ids, known, title, nonempty=False):
        require(isinstance(ids, list) and len(ids) == len(set(ids)), f"{title}重复")
        require(set(ids).issubset(known), f"{title}引用不存在的编号")
        require(not nonempty or ids, f"{title}不能为空")

    def point(p):
        require(all(type(p[k]) in (int, float) and math.isfinite(p[k]) for k in ("x", "y")), "示意坐标无效")
        require(0 <= p["x"] <= width and 0 <= p["y"] <= height, "示意坐标越界")

    for source in sources.values():
        require(source["title"] and source["license"] and source["note"], "来源说明不完整")
        check_date(source["accessedAt"])
        check_date(source.get("sourcePublishedAt"), optional=True)
        require(source["url"] is None or source["url"].startswith("https://"), "来源网址必须为 HTTPS")
    for district in districts.values():
        require(COLOR.fullmatch(district["color"]), "行政区颜色无效")
        require(len(district["polygon"]) >= 3, "行政区多边形不足三个点")
        for p in district["polygon"]:
            point(p)
        point(district["label"])
    for line in lines.values():
        require(COLOR.fullmatch(line["color"]), "线路颜色无效")
        refs(line["stationIDs"], stations, "线路站点", True)
        require(len(line["stationIDs"]) >= 2, "线路至少需要两个站点")
        require(len(line["termini"]) == 2 and all(line["termini"]), "需要两端终点说明")
        refs(line["sourceIDs"], sources, "线路来源", True)
    for station in stations.values():
        require(station["name"], "站名不能为空")
        refs(station["lineIDs"], lines, "站点线路", True)
        memberships = {key for key, line in lines.items() if station["id"] in line["stationIDs"]}
        require(set(station["lineIDs"]) == memberships, "线路与站点成员关系不一致")
        refs(station["districtIDs"], districts, "行政区")
        require(station["districtIDs"] or station["districtNote"], "未知行政归属需填写说明")
        refs(station["sourceIDs"], sources, "站点来源", True)
        refs(station["coordinateSourceIDs"], sources, "坐标来源", station["coordinate"] is not None)
        coordinate(station["coordinate"])
        if station.get("amapLocation") is not None:
            location = station["amapLocation"]
            require(isinstance(location, dict), "高德站点位置必须为对象")
            require(location.get("system") == "gcj02", "高德站点位置必须明确标注GCJ02")
            require(isinstance(location.get("poiID"), str) and re.fullmatch(r"B[A-Z0-9]+", location["poiID"]), "高德POI编号无效")
            for key, limit in [("latitude", 90), ("longitude", 180)]:
                value = location.get(key)
                require(type(value) in (int, float) and math.isfinite(value) and -limit <= value <= limit, "高德站点坐标无效")
            require(isinstance(location.get("sourceIDs"), list), "高德站点位置缺少来源")
            refs(location["sourceIDs"], sources, "高德位置来源", True)
            check_date(location.get("updatedAt"))

        point(station["diagram"])
        require(all(type(station["labelOffset"][k]) in (int, float) and math.isfinite(station["labelOffset"][k]) for k in ("x", "y")), "文字偏移无效")
        check_date(station["updatedAt"], optional=True)
        index(station["exits"], "出口")
        index(station["timetables"], "时刻")
        review = station.get("serviceReview")
        if review is not None:
            statuses = {"notCollected", "partial", "reviewed", "conflict"}
            require(review["timetableStatus"] in statuses and review["exitStatus"] in statuses, "服务资料核验状态无效")
            check_date(review.get("verifiedAt"), optional=True)
        notices = station.get("serviceNotices") or []
        index(notices, "日期调整说明")
        for notice in notices:
            require(notice["text"].strip(), "日期调整说明为空")
            refs(notice["sourceIDs"], sources, "日期调整说明来源", True)
            check_date(notice["verifiedAt"])
            for key in ("validFrom", "validThrough"):
                check_date(notice.get(key), optional=True)
            for day in notice["serviceDates"]:
                check_date(day)
            require(len(notice["serviceDates"]) == len(set(notice["serviceDates"])) and
                    notice["serviceDates"] == sorted(notice["serviceDates"]), "日期调整说明适用日期重复或未排序")
            require(notice["serviceDates"] or notice.get("validFrom") is not None, "日期调整说明缺少明确适用日期")
            if notice.get("validFrom") is not None and notice.get("validThrough") is not None:
                require(notice["validFrom"] <= notice["validThrough"], "日期调整说明有效期倒置")
        for entry in station["exits"]:
            description = entry.get("description")
            require(entry["name"].strip() and (description is None and data["schemaVersion"] == 2 or
                    isinstance(description, str) and description.strip()), "出口信息不完整")
            coordinate(entry["coordinate"])
            refs(entry["sourceIDs"], sources, "出口来源", True)
            check_date(entry["updatedAt"])
            check_date(entry.get("verifiedAt"), optional=True)
        for timetable in station["timetables"]:
            require(timetable["lineID"] in station["lineIDs"], "时刻表线路不经过本站")
            require(timetable["direction"].strip() and timetable["serviceDays"].strip(), "时刻必须有方向及适用条件")
            refs(timetable["sourceIDs"], sources, "时刻来源", True)
            check_date(timetable["updatedAt"])
            check_date(timetable.get("verifiedAt"), optional=True)
            check_date(timetable.get("validFrom"), optional=data["schemaVersion"] == 2)
            if data["schemaVersion"] == 2 and timetable.get("serviceLabel") is not None:
                require(timetable["serviceLabel"].strip(), "特殊服务标签为空")
            check_date(timetable["validThrough"], optional=True)
            if timetable.get("validFrom") is not None and timetable["validThrough"] is not None:
                require(timetable["validThrough"] >= timetable["validFrom"], "时刻有效期倒置")
            first = check_time(timetable["first"]) if timetable["first"] is not None else None
            last = check_time(timetable["last"]) if timetable["last"] is not None else None
            require(first is not None or last is not None, "空时刻不应写入数组")
            require(first is None or last is None or last >= first, "末班早于首班，请检查次日标记")
    review = data.get("networkReview")
    if review is not None:
        require(isinstance(review, dict), "线网核验必须为对象")
        check_date(review.get("reviewedAt"))
        check_date(data["dataAsOf"])
        refs(review.get("sourceIDs", []), sources, "线网核验来源", True)
        for key, expected in [("lineCount", len(lines)), ("stationCount", len(stations)),
                              ("membershipCount", sum(len(l["stationIDs"]) for l in lines.values()))]:
            require(type(review.get(key)) is int and review[key] == expected, "线网核验计数与资料不一致")
        if districts:
            for district in districts.values():
                require(polygon_contains(district['label'], district['polygon']), f"区名必须位于对应底色内：{district['name']}")
            for station in stations.values():
                if not station['districtIDs']:
                    continue  # Unknown district IDs remain empty; diagram color never assigns them.
                covered = {d['id'] for d in districts.values() if polygon_contains(station['diagram'], d['polygon'])}
                require(covered and covered.issubset(station['districtIDs']), f"站点底色与行政区不一致：{station['name']}")
    for service in data.get("throughServices") or []:
        endpoints = [service["fromStationID"], service["toStationID"]]
        refs(endpoints, stations, "贯通端点", True)
        refs(service["lineIDs"], lines, "贯通线路", True)
        require(len(service["lineIDs"]) == 2 and service.get("note"), "贯通说明缺失")
        for station, line in zip(endpoints, service["lineIDs"]):
            ordered = lines[line]["stationIDs"]
            require(station in [ordered[0], ordered[-1]], "贯通连接必须连接对应线路端点")
    for item in list(stations.values()) + list(lines.values()):
        for key in ("diagramPath", "diagramMarkerPath"):
            if item.get(key) is not None:
                check_svg_path(item[key])
        if item.get("badgePosition") is not None:
            point(item["badgePosition"])
        if item.get("labelAnchor") is not None:
            require(item["labelAnchor"] in ("start", "end", "middle"), "文字对齐方式无效")
    if production or (not data["isSample"] and (review is None or data.get("coverageReview") is not None)):
        require(not data["isSample"], "示例资料不能作为正式全线网发布")
        check_date(data["dataAsOf"])
        approval = data.get("coverageReview") or {}
        require(approval.get("reviewer") and approval.get("completeNetwork") is True, "缺少完整发布核验记录")
        require(approval.get("usageRightsConfirmed") is True, "资料使用条件尚未确认")
        require(approval.get("districtsReviewed") is True and districts and all(s["districtIDs"] for s in stations.values()), "行政区归属尚未核验")
        check_date(approval.get("reviewedAt"))
        refs(approval.get("sourceIDs", []), sources, "核验来源", True)
        require(all(station["coordinate"] is not None for station in stations.values()), "正式资料需要所有站点的已核验真实坐标")


def render_svg(data):
    esc = lambda value: html.escape(str(value), quote=True)
    width, height = data["map"]["width"], data["map"]["height"]
    result = [f'<svg xmlns="http://www.w3.org/2000/svg" id="metro-map" viewBox="0 0 {width} {height}" role="group" aria-label="{esc(data["cityName"])}地铁示意图">']
    result.append('<style>text{font-family:-apple-system,BlinkMacSystemFont,sans-serif;fill:#243c3a}.line{fill:none;stroke-width:9;stroke-linejoin:round;stroke-linecap:round}.station-label{font-size:21px;font-weight:600;paint-order:stroke;stroke:#fff;stroke-width:5px;stroke-linejoin:round}.station-dot{fill:white;stroke:#34534b;stroke-width:3}.selected .station-dot{fill:#e6b83e;stroke:#132f29;stroke-width:5}.district-label{font-size:35px;fill:#6b817c;letter-spacing:5px}.station,.line-group{cursor:pointer}.line-hit{fill:none;stroke:transparent;stroke-width:32}</style>')
    if data.get('networkReview'):
        result.append('<style>.station-label{font-size:27px;font-weight:500;stroke-width:4px}.line{stroke-width:13px}.district-label{font-size:58px;font-weight:600;fill:#657970;letter-spacing:8px}</style>')
    result.append(f'<rect width="{width}" height="{height}" fill="#f8faf5"/>')
    result.append(render_background(data))
    for district in data["districts"]:
        points = " ".join(f'{p["x"]},{p["y"]}' for p in district["polygon"])
        p = district["label"]
        result.append(f'<g id="district-{district["id"]}" data-district="{district["id"]}" pointer-events="none"><title>{esc(district["note"] or "示意区界")}</title><polygon points="{points}" fill="{district["color"]}" stroke="#aabbb1" stroke-width="3"/><text x="{p["x"]}" y="{p["y"]}" class="district-label">{esc(district["name"])}</text></g>')
    result.append(render_boundaries(data))
    stations = {s["id"]: s for s in data["stations"]}
    for line in data["lines"]:
        points = " ".join(f'{stations[s]["diagram"]["x"]},{stations[s]["diagram"]["y"]}' for s in line["stationIDs"])
        first = stations[line["stationIDs"][0]]["diagram"]
        badge = line.get("badgePosition")
        bx, by = (badge["x"], badge["y"]) if badge else (first["x"], first["y"]-50)
        if line.get("diagramPath"):
            geometry = f'<path d="{esc(line["diagramPath"])}" class="line-hit"/><path d="{esc(line["diagramPath"])}" class="line" stroke="{line["color"]}"/>'
        else:
            geometry = f'<polyline points="{points}" class="line-hit"/><polyline points="{points}" class="line" stroke="{line["color"]}"/>' 
        result.append(f'<g id="line-{line["id"]}" class="line-group" data-line="{line["id"]}">{geometry}<rect x="{bx-30}" y="{by-30}" width="60" height="60" rx="8" fill="{line["color"]}"/><text x="{bx}" y="{by+11}" text-anchor="middle" style="fill:white;font-size:32px;font-weight:700">{esc(line["shortName"])}</text></g>')
    for station in data["stations"]:
        x, y = station["diagram"]["x"], station["diagram"]["y"]
        dx, dy = station["labelOffset"]["x"], station["labelOffset"]["y"]
        anchor = station.get("labelAnchor", "end" if dx < 0 else "start")
        transfer = len(station["lineIDs"]) > 1
        marker = f'<path class="station-dot" d="{esc(station["diagramMarkerPath"])}"/>' if transfer and station.get("diagramMarkerPath") else f'<circle class="station-dot" cx="{x}" cy="{y}" r="{12 if transfer else 7}"/>'
        result.append(f'<g id="station-{station["id"]}" class="station" data-station="{station["id"]}" data-lines="{esc(" ".join(station["lineIDs"]))}" data-x="{x}" data-y="{y}" role="button" tabindex="0" aria-label="{esc(station["name"])}站"><title>{esc(station["name"])}</title><circle cx="{x}" cy="{y}" r="22" fill="transparent"/>{marker}')
        if transfer and not station.get("diagramMarkerPath"):
            result.append(f'<circle cx="{x}" cy="{y}" r="5" fill="#34534b" pointer-events="none"/>')
        suffix = ' ↗' if station['name'] in ('湖贝','红岭南','福田口岸') else ''
        result.append(f'<text x="{x+dx}" y="{y+dy}" class="station-label" text-anchor="{anchor}">{esc(station["name"]+suffix)}</text>')
        result.append('</g>')
    result.append(render_foreground(data))
    result.append('</svg>')
    return "\n".join(result)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def build(data, output, production=False):
    validate(data, production)
    output.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode()
    svg = render_svg(data).encode()
    manifest = {"schemaVersion": data["schemaVersion"], "cityID": data["cityID"], "version": data["version"],
                "files": {"city.json": digest(payload), "map.svg": digest(svg)}}
    # Build outside the App when preparing a replacement; move the whole validated directory together.
    (output / "city.json").write_bytes(payload)
    (output / "map.svg").write_bytes(svg)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    verify_bundle(output)


def verify_bundle(folder):
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    require(isinstance(manifest, dict) and type(manifest.get("schemaVersion")) is int and
            manifest["schemaVersion"] in (1, 2), "不支持的 manifest schemaVersion")
    require(isinstance(manifest.get("files"), dict) and set(manifest["files"]) == {"city.json", "map.svg"}, "manifest 文件集合无效")
    for name, expected in manifest["files"].items():
        require(digest((folder / name).read_bytes()) == expected, f"{name} 哈希不匹配")
    data = json.loads((folder / "city.json").read_text(encoding="utf-8"))
    validate(data)
    require(data["schemaVersion"] == manifest["schemaVersion"] and data["cityID"] == manifest.get("cityID") and
            data["version"] == manifest.get("version"), "资料版本不一致")
    root = ET.parse(folder / "map.svg").getroot()
    context = data.get('mapContext')
    if context:
        legends = [n.attrib['data-legend-line'] for n in root.iter() if 'data-legend-line' in n.attrib]
        require(len(legends) == len(set(legends)) and set(legends) == {l['id'] for l in data['lines']}, 'SVG线路图例与JSON不匹配')
        for attribute, collection in [('data-map-area', 'areas'), ('data-boundary', 'boundaries'),
                                      ('data-map-inset', 'insets'), ('data-map-focus', 'focusAreas')]:
            values = [element.attrib[attribute] for element in root.iter() if attribute in element.attrib]
            require(len(values) == len(set(values)) and set(values) == {i['id'] for i in context[collection]},
                    f'SVG外围对象 {collection} 与JSON不匹配')

    for attribute, collection in [("data-station", "stations"), ("data-line", "lines"), ("data-district", "districts")]:
        values = [element.attrib[attribute] for element in root.iter() if attribute in element.attrib]
        require(len(values) == len(set(values)) and set(values) == {i["id"] for i in data[collection]}, f"SVG {collection} 与 JSON 不匹配")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "build"):
        child = sub.add_parser(name)
        child.add_argument("source", type=Path)
        child.add_argument("--production", action="store_true")
        if name == "build":
            child.add_argument("output", type=Path)
    check = sub.add_parser("verify")
    check.add_argument("folder", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "verify":
            verify_bundle(args.folder)
        else:
            data = json.loads(args.source.read_text(encoding="utf-8"))
            validate(data, args.production)
            if args.command == "build":
                build(data, args.output, args.production)
        print("PASS: 城市资料包检查通过" + ("（含正式资料门槛）" if getattr(args, "production", False) else ""))
    except (ValueError, KeyError, TypeError, OSError, ET.ParseError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
