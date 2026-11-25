#!/usr/bin/env python3
"""Pregled i ocenjivanje dnevnika review nalaza.

    review_log.py list [--profil IME] [--svi]     otvoreni nalazi (sa --svi i ocenjeni)
    review_log.py mark ID OCENA [NAPOMENA]        OCENA: prihvacen | odbijen | sum
    review_log.py stats [--profil IME]            koliko nalaza je korisno, po izvoru, nivou i ozbiljnosti

Dnevnici se nalaze preko profila: svaki profil ima `log:` liniju.
"""

import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone

KIT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
OUTCOMES = ("prihvacen", "odbijen", "sum")


def profile_dirs() -> list[str]:
    configured = os.environ.get("REVIEW_KIT_PROFILES", os.path.expanduser("~/.review-kit/profiles"))
    return [d for d in configured.split(":") if os.path.isdir(d)] + [os.path.join(KIT, "profiles")]


def log_files() -> dict[str, str]:
    """Map profile name to its log path, for every profile that has one."""
    logs: dict[str, str] = {}
    for directory in profile_dirs():
        for name in sorted(os.listdir(directory)):
            if not name.endswith(".yaml"):
                continue
            fields = {}
            with open(os.path.join(directory, name)) as f:
                for line in f:
                    key, sep, value = line.partition(":")
                    if sep and not line.startswith("#"):
                        fields[key.strip()] = value.split(" #")[0].strip()
            if fields.get("name") and fields.get("log"):
                logs.setdefault(fields["name"], os.path.expanduser(fields["log"]))
    return logs


def read_entries(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def write_entries(path: str, entries: list[dict]) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        for entry in entries:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    os.replace(tmp, path)


def selected_logs(args: list[str]) -> dict[str, str]:
    logs = log_files()
    if "--profil" in args:
        name = args[args.index("--profil") + 1]
        if name not in logs:
            sys.exit(f"GRESKA: nema profila {name}; postoje: {', '.join(logs)}")
        return {name: logs[name]}
    return logs


def cmd_list(args: list[str]) -> int:
    show_all = "--svi" in args
    shown = 0
    for profile, path in selected_logs(args).items():
        entries = [e for e in read_entries(path) if show_all or e.get("outcome") is None]
        if not entries:
            continue
        print(f"\n## {profile} ({path})")
        last_review = None
        for e in entries:
            review = e["id"].rsplit("-", 1)[0]
            if review != last_review:
                where = e.get("url") or f"{e.get('kind')} {e.get('target')}"
                print(f"\n  {e['date'][:10]}  {e['level']}  {where}  sha {e['head_sha'][:7]}")
                last_review = review
            outcome = e.get("outcome") or "-"
            location = f"{e.get('file')}:{e.get('line')}" if e.get("file") else "cela promena"
            sources = ",".join(e.get("sources") or [])
            print(f"    {e['id']:<14} {outcome:<10} {e['severity']:<11} {e['title']}")
            print(f"    {'':<14} {location} [{sources}]")
            shown += 1
    if not shown:
        print("Nema nalaza za prikaz.")
    return 0


def cmd_mark(args: list[str]) -> int:
    if len(args) < 2 or args[1] not in OUTCOMES:
        sys.exit(f"upotreba: mark ID {'|'.join(OUTCOMES)} [napomena]")
    finding_id, outcome, note = args[0], args[1], " ".join(args[2:]) or None
    for profile, path in log_files().items():
        entries = read_entries(path)
        for e in entries:
            if e["id"] == finding_id:
                e["outcome"] = outcome
                e["outcome_note"] = note
                e["outcome_date"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
                write_entries(path, entries)
                print(f"OZNACENO: {finding_id} = {outcome} ({profile})")
                return 0
    sys.exit(f"GRESKA: nalaz {finding_id} ne postoji ni u jednom dnevniku")


def rate_table(title: str, groups: dict[str, list[dict]]) -> None:
    print(f"\n### {title}")
    print(f"  {'':<22} {'ukupno':>6} {'ocenj.':>6} {'prihv.':>6} {'odbij.':>6} {'sum':>5} {'korisno':>8}")
    for key in sorted(groups):
        items = groups[key]
        rated = [e for e in items if e.get("outcome")]
        counts = {o: sum(1 for e in rated if e["outcome"] == o) for o in OUTCOMES}
        useful = f"{100 * counts['prihvacen'] / len(rated):.0f}%" if rated else "-"
        print(f"  {key:<22} {len(items):>6} {len(rated):>6} {counts['prihvacen']:>6} "
              f"{counts['odbijen']:>6} {counts['sum']:>5} {useful:>8}")


def cmd_stats(args: list[str]) -> int:
    entries = [e for path in selected_logs(args).values() for e in read_entries(path)]
    if not entries:
        print("Dnevnik je prazan.")
        return 0
    by_source: dict[str, list[dict]] = defaultdict(list)
    for e in entries:
        for source in e.get("sources") or ["nepoznat"]:
            by_source[source].append(e)
    by_level: dict[str, list[dict]] = defaultdict(list)
    by_severity: dict[str, list[dict]] = defaultdict(list)
    for e in entries:
        by_level[e.get("level") or "-"].append(e)
        by_severity[e.get("severity") or "-"].append(e)

    reviews = len({e["id"].rsplit("-", 1)[0] for e in entries})
    rated = sum(1 for e in entries if e.get("outcome"))
    print(f"{reviews} review-a, {len(entries)} nalaza, {rated} ocenjeno")
    print("korisno = prihvaceni / ocenjeni; nalaz sa vise izvora se racuna svakom izvoru")
    rate_table("Po izvoru", by_source)
    rate_table("Po nivou", by_level)
    rate_table("Po ozbiljnosti", by_severity)
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    command, args = sys.argv[1], sys.argv[2:]
    handlers = {"list": cmd_list, "mark": cmd_mark, "stats": cmd_stats}
    if command not in handlers:
        print(__doc__)
        return 2
    return handlers[command](args)


if __name__ == "__main__":
    sys.exit(main())
