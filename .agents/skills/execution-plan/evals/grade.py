#!/usr/bin/env python3
"""Mechanical checks for iteration runs. Prints JSON {check: {passed, evidence}}.

Usage: grade.py <skill-dir> <eval-name> <repo-dir> <fixture-dir>
"""
import filecmp, glob, json, os, re, shutil, subprocess, sys, tempfile

skill, name, repo, fixture = sys.argv[1:5]
unit = os.path.join(repo, "src/billing/invoices")
out = {}


def run(cmd, cwd):
    p = subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True, timeout=120)
    return p.returncode, (p.stdout + p.stderr).strip()


def record(key, passed, evidence):
    out[key] = {"passed": bool(passed), "evidence": evidence[-600:]}


def contract_tests():
    found = []
    for path in glob.glob(os.path.join(repo, "**/*"), recursive=True):
        if "node_modules" in path or not os.path.isfile(path):
            continue
        if os.path.commonpath([path, unit]) == unit:
            continue  # inside the disposable dir
        if re.search(r"contract", os.path.basename(path)) and re.search(r"\.(m?js|ts)$", path):
            found.append(os.path.relpath(path, repo))
    return sorted(found)


def check_script():
    tests = contract_tests()
    code, text = run(
        f"bash {skill}/evals/check-intent-doc.sh src/billing/invoices {' '.join(tests)}", repo
    )
    record("check-intent-doc.sh", code == 0, f"tests={tests}; exit={code}; {text or 'OK'}")


def npm_test():
    code, text = run("npm test 2>&1 | grep -E '^ℹ (tests|pass|fail)'", repo)
    fail = re.search(r"ℹ fail (\d+)", text)
    record("npm test", fail is not None and fail.group(1) == "0", text)


def bdd_free():
    pkg = open(os.path.join(repo, "package.json")).read()
    hit = re.findall(r'"[^"]*(cucumber|gherkin|bdd)[^"]*"', pkg, re.I)
    record("no BDD dependency", not hit, f"matches={hit}")
    steps = [
        p for p in glob.glob(os.path.join(repo, "**/*"), recursive=True)
        if re.search(r"step[_-]?def|steps\.(m?js|ts)$|\.steps\.", p, re.I)
    ]
    record("no step-definition files", not steps, f"files={steps}")


def src_unchanged():
    cmp = filecmp.dircmp(os.path.join(repo, "src"), os.path.join(fixture, "src"))
    diffs = []

    def walk(c, prefix=""):
        diffs.extend(prefix + f for f in c.diff_files + c.left_only + c.right_only)
        for sub, sc in c.subdirs.items():
            walk(sc, prefix + sub + "/")

    walk(cmp)
    record("src unchanged", not diffs, f"changed={diffs}")


def plan_doc():
    docs = [p for p in glob.glob(os.path.join(repo, "docs/plans/*.md"))
            if re.match(r"\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$", os.path.basename(p))]
    record("plan doc at docs/plans/YYYY-MM-DD-<slug>.md", bool(docs),
           f"found={[os.path.relpath(d, repo) for d in docs]}")



if name in ("plan-with-intent-docs", "plan-without-intent-docs"):
    plan_doc(); src_unchanged()
    if name == "plan-without-intent-docs":
        extra = glob.glob(os.path.join(repo, "**/INTENT.md"), recursive=True) + \
                glob.glob(os.path.join(repo, "**/*.feature"), recursive=True)
        record("no INTENT.md or .feature added", not extra, f"found={extra}")
else:
    sys.exit(f"unknown eval: {name}")

print(json.dumps(out, indent=2))
