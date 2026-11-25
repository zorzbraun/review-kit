import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import post_gate as pg  # noqa: E402

DIFF = """diff --git a/app/x.py b/app/x.py
--- a/app/x.py
+++ b/app/x.py
@@ -10,3 +10,4 @@ def f():
     a = 1
-    b = 2
+    b = 3
+    c = 4
     return a
diff --git a/app/gone.py b/app/gone.py
--- a/app/gone.py
+++ /dev/null
@@ -1,1 +0,0 @@
-x = 1
"""

HEAD = "83ecaef187d149d31b69ebfed56cbcc538cc6e9f"


def finding(**kw):
    base = {"severity": "Advisory", "title": "t", "file": "app/x.py", "line": 11, "problem": "p",
            "confidence": "high", "pre_existing": False}
    base.update(kw)
    return base


class AddedLinesTest(unittest.TestCase):
    def test_only_added_lines_on_new_side(self):
        self.assertEqual(pg.added_lines(DIFF), {"app/x.py": {11, 12}})

    def test_empty(self):
        self.assertEqual(pg.added_lines(""), {})


class LabelTest(unittest.TestCase):
    def test_labels(self):
        self.assertEqual(pg.label({"severity": "Must fix"}), "Must fix")
        self.assertEqual(pg.label({"severity": "Should fix"}), "Should fix")
        self.assertEqual(pg.label({"severity": "Advisory", "pre_existing": True}), "Follow-up")
        self.assertEqual(pg.label({"severity": "Advisory"}), "Optional")

    def test_inline_body_has_label_trigger_and_fix(self):
        body = pg.inline_body(finding(severity="Should fix", trigger="X", fix="Y", why="W"))
        self.assertTrue(body.startswith("**Should fix:** t"))
        self.assertIn("Trigger: X", body)
        self.assertIn("Suggestion: Y", body)
        self.assertIn("Why it matters: W", body)


class EvaluateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = self.tmp.name
        os.makedirs(os.path.join(self.out, "findings"))
        self.write("context.env", f"HEAD_SHA={HEAD}\n")
        self.write("diff.patch", DIFF)
        self.write("comment.md", "Deep review at 83ecaef1 (code read, no tests run).\n")
        self.write_json("findings/logic.json", [])
        self.write_json("checks.json", {"claims": [{"claim": "c", "verdict": "holds"}],
                                        "tests_run": False, "not_verified": []})
        self.write_json("findings/final.json", [finding(severity="Should fix", verified=True)])

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, text):
        with open(os.path.join(self.out, name), "w") as f:
            f.write(text)

    def write_json(self, name, data):
        self.write(name, json.dumps(data))

    def test_passes_and_plans_inline(self):
        reasons, plan = pg.evaluate(self.out, ["logic"], HEAD)
        self.assertEqual(reasons, [])
        self.assertEqual(len(plan["inline"]), 1)
        self.assertEqual(plan["inline"][0]["line"], 11)

    def test_missing_source_fails(self):
        reasons, _ = pg.evaluate(self.out, ["logic", "contracts"], HEAD)
        self.assertTrue(any("contracts" in r for r in reasons))

    def test_unverified_should_fix_fails(self):
        self.write_json("findings/final.json", [finding(severity="Should fix")])
        reasons, _ = pg.evaluate(self.out, ["logic"], HEAD)
        self.assertTrue(any("nije proveren" in r for r in reasons))

    def test_head_changed_or_unchecked_fails(self):
        reasons, _ = pg.evaluate(self.out, ["logic"], "deadbeef" * 5)
        self.assertTrue(any("head se promenio" in r for r in reasons))
        reasons, _ = pg.evaluate(self.out, ["logic"], None)
        self.assertTrue(any("nije proveren" in r for r in reasons))

    def test_tests_not_run_must_be_stated(self):
        self.write("comment.md", "Looks fine.\n")
        reasons, _ = pg.evaluate(self.out, ["logic"], HEAD)
        self.assertTrue(any("no tests run" in r for r in reasons))

    def test_claim_without_verdict_fails(self):
        self.write_json("checks.json", {"claims": [{"claim": "c"}], "tests_run": True, "not_verified": []})
        reasons, _ = pg.evaluate(self.out, ["logic"], HEAD)
        self.assertTrue(any("bez presude" in r for r in reasons))

    def test_line_outside_added_lines_goes_to_summary_and_low_confidence_is_dropped(self):
        self.write_json("findings/final.json", [
            finding(line=10),
            finding(file=None, line=None, title="whole change"),
            finding(line=12, confidence="low", title="weak"),
        ])
        reasons, plan = pg.evaluate(self.out, ["logic"], HEAD)
        self.assertEqual(reasons, [])
        self.assertEqual(plan["inline"], [])
        self.assertEqual(len(plan["summary_only"]), 2)
        self.assertEqual(plan["dropped_low_confidence"], ["weak"])


if __name__ == "__main__":
    unittest.main()
