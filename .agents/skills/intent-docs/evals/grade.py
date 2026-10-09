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



def mutation(label, file_rel, old, new):
    """Contract tests must fail when the implementation is mutated."""
    tmp = tempfile.mkdtemp()
    shutil.copytree(repo, tmp, dirs_exist_ok=True)
    path = os.path.join(tmp, file_rel)
    text = open(path).read()
    if old not in text:
        record(f"contract tests catch {label}", False, f"could not apply mutation: {old!r} not in {file_rel}")
        return
    open(path, "w").write(text.replace(old, new, 1))
    tests = " ".join(contract_tests())
    code, out = run(f"node --test {tests} 2>&1 | grep -E '^ℹ fail'", tmp)
    m = re.search(r"ℹ fail (\d+)", out)
    record(f"contract tests catch {label}", m is not None and m.group(1) != "0", out or "no output")


def identical(rel):
    same = filecmp.cmp(os.path.join(repo, rel), os.path.join(fixture, rel), shallow=False)
    record(f"{rel} byte-identical", same, "identical" if same else "differs")


if name == "write-from-code":
    check_script(); npm_test(); bdd_free()
    mutation("grace period 3 -> 4 days", "src/billing/invoices/fees.js", "GRACE_DAYS = 3", "GRACE_DAYS = 4")
    mutation("flat fee 2500 -> 2400", "src/billing/invoices/fees.js", "FLAT_FEE_CENTS = 2500", "FLAT_FEE_CENTS = 2400")
elif name == "change-behavior":
    check_script(); npm_test(); bdd_free()
    # New contract tests must fail on the original implementation.
    tmp = tempfile.mkdtemp()
    shutil.copytree(repo, tmp, dirs_exist_ok=True)
    for f in glob.glob(os.path.join(tmp, "src/billing/invoices/*.js")):
        os.remove(f)
    for f in glob.glob(os.path.join(fixture, "src/billing/invoices/*.js")):
        shutil.copy(f, os.path.join(tmp, "src/billing/invoices/"))
    shutil.copy(os.path.join(fixture, "src/billing/invoices.js"), os.path.join(tmp, "src/billing/"))
    code, text = run("node --test src/billing/invoices.contract.test.js 2>&1 | grep -E '^(✖|ℹ fail)'", tmp)
    failing = re.search(r"ℹ fail (\d+)", text)
    record("new contract tests fail on original code",
           failing is not None and failing.group(1) != "0", text)
elif name == "refactor-leaves-intent":
    for rel in ["src/billing/invoices/INTENT.md", "src/billing/invoices/invoices.feature",
                "src/billing/invoices.contract.test.js", "src/billing/invoices.js"]:
        identical(rel)
    new = sorted(set(os.listdir(unit)) - set(os.listdir(os.path.join(fixture, "src/billing/invoices"))))
    record("new file under src/billing/invoices/", bool(new), f"new={new}")
    npm_test()
elif name == "refactor-changes-surface":
    check_script(); npm_test()
    changed = not filecmp.cmp(os.path.join(unit, "INTENT.md"),
                              os.path.join(fixture, "src/billing/invoices/INTENT.md"), shallow=False)
    record("INTENT.md changed", changed, "changed" if changed else "identical to fixture")
elif name == "no-bdd-framework":
    bdd_free(); check_script(); npm_test()
else:
    sys.exit(f"unknown eval: {name}")

print(json.dumps(out, indent=2))
