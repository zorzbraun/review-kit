#!/usr/bin/env python3
"""Rezultati benchmark-a: upis jednog prolaza i tabela po nivou i izvoru.

    results.py add <results.jsonl> <case_id> <nivo> <final.json> <judge.json> <trajanje_s>
    results.py table <results.jsonl> [--run RUN_ID]

Najnoviji prolaz se prikazuje ako --run nije dat. RUN_ID je datum pokretanja (YYYY-MM-DD) plus
kratak sha kita, pa se rezultati posle izmene kita ne mesaju sa starim.
"""

import json
import os
import subprocess
import sys
from collections import defaultdict
from datetime import date

KIT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))


def kit_version() -> str:
    """Short sha of the kit plus a dirty marker, so results stay tied to the exact rules used."""
    sha = subprocess.run(["git", "-C", KIT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
    dirty = subprocess.run(["git", "-C", KIT, "status", "--porcelain"], capture_output=True, text=True)
    version = sha.stdout.strip() or "nema-commit"
    return version + ("+izmene" if dirty.stdout.strip() else "")


def cmd_add(args: list[str]) -> int:
    results_path, case_id, level, final_path, judge_path, duration = args
    with open(final_path) as f:
        findings = json.load(f)
    with open(judge_path) as f:
        judge = json.load(f)
    hit_index = judge.get("finding_index")
    hit_finding = findings[hit_index] if judge.get("hit") and hit_index is not None else {}
    entry = {
        "run": f"{date.today().isoformat()}@{kit_version()}",
        "case": case_id,
        "level": level,
        "hit": bool(judge.get("hit")),
        "near_miss": bool(judge.get("near_miss")),
        "hit_severity": hit_finding.get("severity"),
        "hit_sources": hit_finding.get("sources"),
        "findings": len(findings),
        "must_fix": sum(1 for f in findings if f.get("severity") == "Must fix"),
        "duration_s": int(float(duration)),
        "reason": judge.get("reason"),
    }
    os.makedirs(os.path.dirname(os.path.abspath(results_path)), exist_ok=True)
    with open(results_path, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    mark = "POGODAK" if entry["hit"] else ("BLIZU" if entry["near_miss"] else "PROMASAJ")
    print(f"{case_id} {level}: {mark} ({entry['findings']} nalaza, {entry['duration_s']}s)")
    return 0


def _avg_duration(items: list[dict]) -> str:
    known = [e["duration_s"] for e in items if e.get("duration_s") is not None]
    return f"{sum(known) / len(known):>9.0f}s" if known else f"{'-':>10}"


def cmd_table(args: list[str]) -> int:
    results_path = args[0]
    with open(results_path) as f:
        entries = [json.loads(line) for line in f if line.strip()]
    if not entries:
        print("Nema rezultata.")
        return 0
    run = args[args.index("--run") + 1] if "--run" in args else entries[-1]["run"]
    entries = [e for e in entries if e["run"] == run]
    print(f"Prolaz {run}, {len({e['case'] for e in entries})} slucajeva\n")

    by_level: dict[str, list[dict]] = defaultdict(list)
    for e in entries:
        by_level[e["level"]].append(e)
    print(f"  {'nivo':<10} {'slucaj.':>7} {'pogodak':>8} {'blizu':>6} {'recall':>7} {'nalaza/sl.':>10} {'Must/sl.':>9} {'vreme/sl.':>10}")
    for level, items in sorted(by_level.items()):
        n = len(items)
        hits = sum(e["hit"] for e in items)
        print(f"  {level:<10} {n:>7} {hits:>8} {sum(e['near_miss'] for e in items):>6} {100 * hits / n:>6.0f}% "
              f"{sum(e['findings'] for e in items) / n:>10.1f} {sum(e['must_fix'] for e in items) / n:>9.1f} "
              f"{_avg_duration(items)}")

    sources: dict[str, int] = defaultdict(int)
    for e in entries:
        for s in e.get("hit_sources") or []:
            sources[f"{e['level']}:{s}"] += 1
    if sources:
        print("\n  Ko je nasao pogotke (nalaz sa vise izvora se racuna svakom):")
        for key, count in sorted(sources.items(), key=lambda kv: -kv[1]):
            print(f"    {key:<32} {count}")

    print("\n  Po slucaju:")
    cases = sorted({e["case"] for e in entries})
    levels = sorted(by_level)
    print(f"    {'slucaj':<16} " + " ".join(f"{lv:>10}" for lv in levels))
    for case in cases:
        row = []
        for level in levels:
            match = [e for e in entries if e["case"] == case and e["level"] == level]
            row.append("-" if not match else ("POGODAK" if match[0]["hit"] else ("blizu" if match[0]["near_miss"] else "promasaj")))
        print(f"    {case:<16} " + " ".join(f"{r:>10}" for r in row))
    return 0


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in ("add", "table"):
        print(__doc__)
        return 2
    if sys.argv[1] == "add" and len(sys.argv) != 8:
        print(__doc__)
        return 2
    return cmd_add(sys.argv[2:]) if sys.argv[1] == "add" else cmd_table(sys.argv[2:])


if __name__ == "__main__":
    sys.exit(main())
