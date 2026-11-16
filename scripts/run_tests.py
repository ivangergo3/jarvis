#!/usr/bin/env python3
"""Fail-closed Swift Testing gate. No third-party Python dependencies."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 128 * 1024


def redact(text):
    text = text.replace(str(Path.home()), "<home>")
    text = re.sub(r"/(?:private/)?(?:var/folders|tmp)/[^\s\"<>]+", "<temporary-path>", text)
    return re.sub(r"(?i)(authorization|token|password|secret)(\s*[:=]\s*)\S+", r"\1\2<redacted>", text)


def test_id(value):
    return value.split("(", 1)[0]


def validate(reports, discovered, required):
    cases = []
    for report in reports:
        if report.stat().st_size > 8 * 1024 * 1024:
            raise ValueError("Oversized test report")
        root = ET.parse(report).getroot()
        cases.extend(root.iter("testcase"))
        for suite in root.iter("testsuite"):
            for key in ("failures", "errors", "skipped"):
                if float(suite.get(key, "0")) != 0:
                    raise ValueError(f"Report contains {key}")
    if not cases:
        raise ValueError("Zero test cases reported (or missing report)")
    for case in cases:
        if any(case.find(tag) is not None for tag in ("failure", "error", "skipped")):
            raise ValueError("Failed, errored or skipped test case")
        if case.get("status", "").lower() in ("skipped", "disabled", "notrun"):
            raise ValueError("Unexecuted test case")
    executed = {test_id(c.get("classname", "") + "/" + c.get("name", "")) for c in cases}
    if not discovered:
        raise ValueError("Zero tests discovered")
    missing = (discovered | required) - executed
    if missing:
        raise ValueError("Tests missing from results: " + ", ".join(sorted(missing)))
    if required - discovered:
        raise ValueError("Critical tests missing from discovery")
    return len(cases)


def run(command, log, timeout):
    # A separate process group ensures a timed-out runner cannot leave test children behind.
    with log.open("wb") as output:
        process = subprocess.Popen(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise ValueError("Test command exceeded its time limit")


def tail(path):
    if not path.exists():
        return ""
    with path.open("rb") as stream:
        stream.seek(max(0, path.stat().st_size - LIMIT))
        return redact(stream.read(LIMIT).decode("utf-8", errors="replace"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift-arg", action="append", default=[], help="Extra SwiftPM argument; use = for flags")
    parser.add_argument("--output", type=Path, default=ROOT / "test-results")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    summary = {"passed": False, "test_cases": 0}
    with tempfile.TemporaryDirectory(prefix="jarvis-tests-") as folder:
        folder = Path(folder)
        log = folder / "tests.log"
        discovery = folder / "discovery.log"
        try:
            status = run(["swift", "test", *args.swift_arg, "--xunit-output", str(folder / "results.xml")], log, 600)
            summary["process_exit"] = status
            if status != 0:
                raise ValueError(f"Swift test process failed with exit {status}")
            if run(["swift", "test", "list", "--skip-build", *args.swift_arg], discovery, 60) != 0:
                raise ValueError("Test discovery process failed")
            discovered = {test_id(line.strip()) for line in discovery.read_text().splitlines()
                          if re.fullmatch(r"JarvisTests\.[^/\s]+/[^\s]+", line.strip())}
            required = set(json.loads((ROOT / "scripts/critical-tests.json").read_text()))
            # SwiftPM versions may emit a separate *-swift-testing.xml alongside empty XCTest XML.
            summary["test_cases"] = validate(list(folder.glob("*.xml")), discovered, required)
            summary["passed"] = True
        except (ValueError, OSError, ET.ParseError) as error:
            summary["error"] = redact(str(error))
        finally:
            (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
            (args.output / "failure.log").write_text("" if summary["passed"] else tail(log) + "\n" + tail(discovery))
    print(json.dumps(summary, indent=2))
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
