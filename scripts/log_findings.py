#!/usr/bin/env python3
"""Upisuje konacne nalaze jednog review-a u dnevnik profila (JSON linije, bez koda).

    log_findings.py <OUT folder> <findings.json> <nivo>

Svaki nalaz dobija `id` i `outcome: null`; /review-log ga kasnije oznacava.
"""

import hashlib
import json
import os
import shlex
import sys
from datetime import datetime, timezone

KEPT_FIELDS = ("severity", "category", "title", "file", "line", "sources", "confidence", "pre_existing")


def read_context(out_dir: str) -> dict[str, str]:
    context = {}
    with open(os.path.join(out_dir, "context.env")) as f:
        for line in f:
            key, _, value = line.rstrip("\n").partition("=")
            if key:
                context[key] = " ".join(shlex.split(value)) if value else ""
    return context


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    out_dir, findings_path, level = sys.argv[1:]
    context = read_context(out_dir)
    with open(os.path.join(out_dir, "meta.json")) as f:
        meta = json.load(f)
    with open(findings_path) as f:
        findings = json.load(f)

    log_path = context["LOG"]
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    review_id = hashlib.sha1(f"{context['REPO']}{context['HEAD_SHA']}{now}".encode()).hexdigest()[:10]

    with open(log_path, "a") as f:
        for index, finding in enumerate(findings):
            entry = {
                "id": f"{review_id}-{index}",
                "date": now,
                "profile": context["PROFILE_NAME"],
                "repo": os.path.basename(context["REPO"]),
                "kind": context["KIND"],
                "target": context["ID"],
                "url": meta.get("url"),
                "head_sha": context["HEAD_SHA"],
                "level": level,
                **{k: finding.get(k) for k in KEPT_FIELDS},
                "outcome": None,
            }
            entry["title"] = (entry["title"] or "")[:100]
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    print(f"DNEVNIK: {len(findings)} nalaza upisano u {log_path} (review {review_id})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
