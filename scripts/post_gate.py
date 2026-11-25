#!/usr/bin/env python3
"""Provera pre nego sto deep-review sam okaci komentar. Ne kaci nista, samo presudjuje.

    post_gate.py <OUT> <izvori zarezom> [--live-head <sha>]

Cita $OUT/findings/*.json, $OUT/findings/final.json, $OUT/checks.json, $OUT/comment.md i
$OUT/diff.patch. Pise $OUT/post-plan.json i ispisuje PROLAZI ili NE PROLAZI sa razlozima.
Izlazni kod je 0 samo kad prolazi.
"""

import json
import os
import re
import shlex
import sys

LABELS = {
    "Must fix": "Must fix",
    "Should fix": "Should fix",
}
_HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")


def label(finding: dict) -> str:
    """Oznaka u komentaru: Must fix, Should fix, Follow-up (problem stariji od promene) ili Optional."""
    severity = finding.get("severity", "Advisory")
    if severity in LABELS:
        return LABELS[severity]
    return "Follow-up" if finding.get("pre_existing") else "Optional"


def added_lines(diff_text: str) -> dict[str, set[int]]:
    """Linije koje promena dodaje, po fajlu (nova strana diffa). Samo na njih ide inline komentar."""
    lines: dict[str, set[int]] = {}
    path = None
    new_line = 0
    for raw in diff_text.splitlines():
        if raw.startswith("+++ "):
            target = raw[4:].strip()
            path = None if target == "/dev/null" else re.sub(r"^b/", "", target)
            continue
        if raw.startswith("--- ") or raw.startswith("diff --git"):
            continue
        match = _HUNK.match(raw)
        if match:
            new_line = int(match.group(1))
            continue
        if path is None or not new_line:
            continue
        if raw.startswith("+"):
            lines.setdefault(path, set()).add(new_line)
            new_line += 1
        elif raw.startswith("-") or raw.startswith("\\"):
            continue
        else:
            new_line += 1
    return lines


def inline_body(finding: dict) -> str:
    """Telo inline komentara: oznaka i naslov, problem, okidac, predlog."""
    parts = [f"**{label(finding)}:** {finding.get('title', '').strip()}", "", finding.get("problem", "").strip()]
    if finding.get("why"):
        parts += ["", f"Why it matters: {finding['why'].strip()}"]
    if finding.get("trigger"):
        parts += ["", f"Trigger: {finding['trigger'].strip()}"]
    if finding.get("fix"):
        parts += ["", f"Suggestion: {finding['fix'].strip()}"]
    return "\n".join(parts).strip() + "\n"


def _load_json(path: str):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def _read_context(out_dir: str) -> dict[str, str]:
    context: dict[str, str] = {}
    try:
        with open(os.path.join(out_dir, "context.env")) as f:
            for line in f:
                key, _, value = line.rstrip("\n").partition("=")
                if key:
                    context[key] = " ".join(shlex.split(value)) if value else ""
    except OSError:
        pass
    return context


def evaluate(out_dir: str, sources: list[str], live_head: str | None) -> tuple[list[str], dict]:
    """Vraca (razlozi zasto ne prolazi, plan kacenja). Prazna lista razloga znaci da prolazi."""
    reasons: list[str] = []
    context = _read_context(out_dir)

    for source in sources:
        data = _load_json(os.path.join(out_dir, "findings", f"{source}.json"))
        if not isinstance(data, list):
            reasons.append(f"izvor {source} nema ispravan JSON niz (nedostupan)")

    final = _load_json(os.path.join(out_dir, "findings", "final.json"))
    if not isinstance(final, list):
        reasons.append("findings/final.json fali ili nije JSON niz")
        final = []

    for finding in final:
        if finding.get("severity") in LABELS and finding.get("verified") is not True:
            reasons.append(f"{finding.get('severity')} nije proveren u kodu: {finding.get('title')}")

    checks = _load_json(os.path.join(out_dir, "checks.json"))
    if not isinstance(checks, dict):
        reasons.append("checks.json fali ili nije JSON objekat")
        checks = {}
    else:
        claims = checks.get("claims")
        if not isinstance(claims, list):
            reasons.append("checks.json nema listu claims")
        else:
            for claim in claims:
                if claim.get("verdict") not in ("holds", "does_not_hold", "unverified"):
                    reasons.append(f"tvrdnja bez presude: {claim.get('claim')}")
        if not isinstance(checks.get("tests_run"), bool):
            reasons.append("checks.json: tests_run mora biti true ili false")
        if not isinstance(checks.get("not_verified"), list):
            reasons.append("checks.json nema listu not_verified")

    try:
        with open(os.path.join(out_dir, "comment.md")) as f:
            comment = f.read()
    except OSError:
        comment = ""
        reasons.append("comment.md fali")
    if checks.get("tests_run") is False and comment and "no tests run" not in comment.lower():
        reasons.append("testovi nisu pokrenuti, a comment.md to ne kaze ('no tests run')")

    head = context.get("HEAD_SHA", "")
    if live_head is None:
        reasons.append("head MR-a uzivo nije proveren")
    elif not head or live_head != head:
        reasons.append(f"head se promenio: pregledan {head[:8] or '?'}, sada {live_head[:8]}; review je zastareo")

    try:
        with open(os.path.join(out_dir, "diff.patch")) as f:
            commentable = added_lines(f.read())
    except OSError:
        commentable = {}
        reasons.append("diff.patch fali")

    plan = {"inline": [], "summary_only": [], "dropped_low_confidence": []}
    for finding in final:
        if finding.get("confidence") == "low":
            plan["dropped_low_confidence"].append(finding.get("title"))
            continue
        path, line = finding.get("file"), finding.get("line")
        if path and isinstance(line, int) and line in commentable.get(path, set()):
            plan["inline"].append({"file": path, "line": line, "label": label(finding),
                                   "title": finding.get("title"), "body": inline_body(finding)})
        else:
            plan["summary_only"].append({"label": label(finding), "title": finding.get("title"),
                                         "file": path, "line": line})
    return reasons, plan


def main() -> int:
    args = sys.argv[1:]
    live_head = None
    if "--live-head" in args:
        i = args.index("--live-head")
        live_head = args[i + 1] if i + 1 < len(args) else ""
        args = args[:i] + args[i + 2:]
    if len(args) != 2:
        print(__doc__)
        return 2
    out_dir, sources_arg = args
    sources = [s.strip() for s in sources_arg.split(",") if s.strip()]
    reasons, plan = evaluate(out_dir, sources, live_head)
    with open(os.path.join(out_dir, "post-plan.json"), "w") as f:
        json.dump(plan, f, indent=2)
    if reasons:
        print("NE PROLAZI")
        for reason in reasons:
            print(f"- {reason}")
        return 1
    print(f"PROLAZI: {len(plan['inline'])} inline, {len(plan['summary_only'])} samo u zbirnom, "
          f"{len(plan['dropped_low_confidence'])} izbaceno (low confidence)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
