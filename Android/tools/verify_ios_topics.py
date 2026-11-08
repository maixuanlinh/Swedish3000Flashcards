#!/usr/bin/env python3
"""Read-only check against this app's released iOS topic source."""
from pathlib import Path
import re

android = Path(__file__).resolve().parents[1]
root = android.parent
swift = (root / "Sources/Models.swift").read_text().split("enum VocabularyTopic:", 1)[1]
kotlin = next((android / "app/src/main/java").rglob("VocabularyTopic.kt")).read_text()

def block(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]

def swift_members(start, end):
    return re.findall(r'\(\.(\w+), "([^"\n]+)"\)', block(swift, start, end))

head = swift_members("private static let headwords:", "private static let coreGroups:")
core_end = "static let ykiThemes:" if "static let ykiThemes:" in swift else "static let themes:"
core = swift_members("private static let coreGroups:", core_end)
# Each pipe-delimited source row is kept verbatim in Kotlin, so word senses and
# group assignment cannot silently drift while labels still appear correct.
for name, words in head:
    assert re.search(re.escape('"' + words + '"') + r'\.split\("\|"\).*?\.add\(' + name + r'\)', kotlin), name
for name, words in core:
    assert re.search(re.escape('"' + words + '"') + r'\.split\("\|"\).*?result\.put\(it,\s*' + name + r'\)', kotlin), name
names = re.findall(r'    case (\w+) = "([^"\n]+)"', swift)
local = "finnish" if "var finnish:" in swift else "swedish"
labels = dict(re.findall(r'case \.(\w+): "([^"\n]+)"', block(swift, "var " + local + ":", "var symbol:")))
for name, title in names:
    assert re.search(r'\b' + name + r'\("' + re.escape(title) + r'",\s*"' + re.escape(labels[name]) + '"', kotlin), name
assert len(names) == 16 and len(head) == 10 and len(core) == 7
print(f"PASS: 9 themes, 7 core groups; all {local} labels and exact headword memberships match iOS.")
