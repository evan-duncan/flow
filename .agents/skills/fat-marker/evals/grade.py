#!/usr/bin/env python3
"""Mechanical checks for iteration runs. Prints JSON {check: {passed, evidence}}.

Usage: grade.py <eval-name> <repo-dir> <fixture-dir>

<fixture-dir> is the invoices-base fixture, used to check src/ is unchanged.
"""
import filecmp, glob, json, os, re, sys

name, repo, fixture = sys.argv[1:4]
out = {}


def record(key, passed, evidence):
    out[key] = {"passed": bool(passed), "evidence": evidence[-600:]}


def src_unchanged():
    diffs = []

    def walk(c, prefix=""):
        diffs.extend(prefix + f for f in c.diff_files + c.left_only + c.right_only)
        for sub, sc in c.subdirs.items():
            walk(sc, prefix + sub + "/")

    walk(filecmp.dircmp(os.path.join(repo, "src"), os.path.join(fixture, "src")))
    record("src unchanged", not diffs, f"changed={diffs}")


def plan_docs():
    return [p for p in glob.glob(os.path.join(repo, "docs/plans/*.md"))
            if re.match(r"\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$", os.path.basename(p))]


def section(doc, heading):
    m = re.search(rf"^## {heading}\b.*?(?=^## |\Z)", doc, re.M | re.S | re.I)
    return m.group(0) if m else ""


def plan_checks():
    docs = plan_docs()
    record("plan doc at docs/plans/YYYY-MM-DD-<slug>.md", docs,
           f"found={[os.path.relpath(d, repo) for d in docs]}")
    if not docs:
        return
    doc = open(docs[0]).read()
    sketch = section(doc, "Sketch")
    record("Sketch section links sketches/statement.png", "sketches/statement.png" in sketch,
           sketch[:300] or "no ## Sketch section")
    layers = re.split(r"^### ", doc, flags=re.M)[1:]
    missing = [l.splitlines()[0] for l in layers if "sketch parts" not in l.lower()]
    record("every layer has a Sketch parts line", layers and not missing,
           f"layers={len(layers)} missing={missing}")
    parts = " ".join(re.findall(r"sketch parts:?\**:?(.*)", doc, re.I))
    record("Download in no layer's Sketch parts", "download" not in parts.lower(), parts[:300])
    record("Download listed under Out of scope", "download" in section(doc, "Out of scope").lower(),
           section(doc, "Out of scope")[:300])


if name == "plan-from-confirmed-sketch":
    plan_checks(); src_unchanged()
elif name in ("read-back-from-canvas", "read-back-from-image"):
    docs = glob.glob(os.path.join(repo, "docs/plans/*.md"))
    record("no planning doc written", not docs, f"found={docs}")
    src_unchanged()
else:
    sys.exit(f"unknown eval: {name}")

print(json.dumps(out, indent=2))
