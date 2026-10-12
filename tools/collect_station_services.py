#!/usr/bin/env python3
"""Cache the public station page's POST responses on the developer computer.

This is not an application runtime dependency or a supported third-party API.
One request at a time; cached successes are reused. Access restrictions stop a run.
"""
import argparse
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'docs/research/station-services-2026-09-28/station-source-index.csv'
STORE = ROOT / 'data/shenzhen/references/station-services'
URL = 'https://www.szmc.net/zdxx'


def read_index():
    with INDEX.open(encoding='utf-8-sig', newline='') as file:
        rows = list(csv.DictReader(file))
    assert len({r['sourceStationCode'] for r in rows}) == len(rows), 'duplicate source code'
    return rows


def collect(codes=None, delay=1.1, refresh=False):
    raw = STORE / 'raw'
    meta = STORE / 'requests'
    raw.mkdir(parents=True, exist_ok=True)
    meta.mkdir(parents=True, exist_ok=True)
    rows = [r for r in read_index() if codes is None or r['sourceStationCode'] in codes]
    failures = []
    for index, row in enumerate(rows):
        code = row['sourceStationCode']
        path, record = raw / f'{code}.json', meta / f'{code}.json'
        if not refresh and path.exists() and record.exists():
            info = json.loads(record.read_text())
            if info.get('status') == 'fetched' and hashlib.sha256(path.read_bytes()).hexdigest() == info['sha256']:
                continue
        timestamp = datetime.now().astimezone().isoformat(timespec='seconds')
        info = dict(code=code, stationID=row['stationID'], stationName=row['stationName'],
                    lineID=row['lineID'], url=URL, method='POST', form={'StieCode': code},
                    pageURL=row['officialPageURL'], retrievedAt=timestamp, status='failed')
        temporary = raw / f'{code}.tmp'
        result = subprocess.run(['curl', '--silent', '--show-error', '--location', '--max-time', '30',
                                 '--output', str(temporary), '--write-out', '%{http_code}',
                                 '--data-urlencode', f'StieCode={code}', URL], capture_output=True, text=True)
        status = result.stdout.strip()
        info['httpStatus'] = status
        try:
            if result.returncode or status != '200':
                raise ValueError(result.stderr.strip() or f'HTTP {status}')
            data = json.loads(temporary.read_text())
            if not isinstance(data, dict) or str(data.get('siteCode')) != code or not data.get('siteName'):
                raise ValueError('Response is not the expected station JSON; no HTML fallback')
            temporary.replace(path)
            info.update(status='fetched', sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        except (ValueError, OSError) as error:
            info['error'] = str(error)
            failures.append(info)
        # Keep failed attempts even after a later successful retry replaces the cache.
        with (STORE / 'request-history.jsonl').open('a') as history:
            history.write(json.dumps(info, ensure_ascii=False) + '\n')
        record.write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n')
        print(f'{index+1}/{len(rows)} {code} {row["stationName"]}: {info["status"]}', flush=True)
        if status in ('401', '403', '429') or (status == '200' and info['status'] != 'fetched'):
            print('Stopped on access restriction or unexpected page. No bypass or alternate endpoint.', flush=True)
            break
        time.sleep(max(1.0, delay))
    (STORE / 'fetch-failures.json').write_text(json.dumps(failures, ensure_ascii=False, indent=2) + '\n')
    return failures


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--codes', nargs='+', help='pilot station codes; omit for the full indexed directory')
    parser.add_argument('--delay', type=float, default=1.1)
    parser.add_argument('--refresh', action='store_true', help='explicitly replace successful cache entries')
    args = parser.parse_args()
    raise SystemExit(bool(collect(set(args.codes) if args.codes else None, args.delay, args.refresh)))
