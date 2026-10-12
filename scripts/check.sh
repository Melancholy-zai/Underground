#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m unittest discover -s tools/tests -v
python3 tools/citypack.py verify App/Resources/CityPack
/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc tools/tests/map_tests.js
swift test --scratch-path /tmp/underground-spm
