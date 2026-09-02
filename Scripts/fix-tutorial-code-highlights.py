#!/usr/bin/env python3
"""Prevent an empty first code panel when entering a DocC tutorial section."""

import json
import sys
from pathlib import Path


def tutorial_tasks(node):
    if isinstance(node, dict):
        if isinstance(node.get("tasks"), list):
            yield from node["tasks"]
        for value in node.values():
            yield from tutorial_tasks(value)
    elif isinstance(node, list):
        for value in node:
            yield from tutorial_tasks(value)


def repair(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    references = data.get("references", {})
    changed = False

    for task in tutorial_tasks(data.get("sections", [])):
        steps = task.get("stepsSection", [])
        first_code = next((step.get("code") for step in steps if step.get("code")), None)
        reference = references.get(first_code) if first_code else None
        if not reference or reference.get("highlights"):
            continue

        content = reference.get("content", [])
        reference["highlights"] = [{"line": line} for line in range(1, len(content) + 1)]
        changed = True

    if changed:
        path.write_text(
            json.dumps(data, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )


archive = Path(sys.argv[1])
for json_path in archive.joinpath("data", "tutorials").rglob("*.json"):
    repair(json_path)
