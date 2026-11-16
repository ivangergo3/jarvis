#!/usr/bin/env python3
"""Prove three critical assertions detect seeded faults, only in a disposable copy.

This is an explicit, slower diagnostic, not an extra build on every pull request.
"""
import argparse
import json
from pathlib import Path
import shutil
import tempfile
import xml.etree.ElementTree as ET

from run_tests import ROOT, redact, run, test_id

FAULTS = [
    ("object-only protocol", "Sources/Jarvis/CodexConnection.swift",
     "case .object = value", "true",
     "JarvisTests.ProtocolBoundaryTests/validJSONThatIsNotAnObjectIsRejected"),
    ("stale refresh revision", "Sources/Jarvis/CompanionModel.swift",
     "revision == historyRevision", "revision == revision",
     "JarvisTests.ConversationRegressionTests/historyStartedBeforeSendCannotEraseTheQueuedMessage"),
    ("stale lifecycle boundary", "Sources/Jarvis/CodexReader.swift",
     "readAt.timeIntervalSince(date) > 1800", "readAt.timeIntervalSince(date) >= 1800",
     "JarvisTests.LifecycleBoundaryTests/startMarkerExpiresOnlyAfterThirtyMinutes"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift-arg", action="append", default=[])
    args = parser.parse_args()
    evidence = []
    with tempfile.TemporaryDirectory(prefix="jarvis-faults-") as directory:
        root = Path(directory)
        for name in ("Sources", "Tests"):
            shutil.copytree(ROOT / name, root / name)
        shutil.copy2(ROOT / "Package.swift", root / "Package.swift")
        for label, path, before, after, selected in FAULTS:
            source = root / path
            original = source.read_text()
            if original.count(before) != 1:
                raise ValueError(f"Mutation anchor changed: {label}; review the fault")
            for defective in (False, True, False):
                source.write_text(original.replace(before, after) if defective else original)
                report = root / "result.xml"
                for old in root.glob("*.xml"):
                    old.unlink()
                log = root / "test.log"
                status = run(["swift", "test", *args.swift_arg, "--filter", selected,
                              "--xunit-output", str(report)], log, 600, cwd=root)
                cases = [case for xml in root.glob("*.xml") for case in ET.parse(xml).getroot().iter("testcase")]
                matching = [case for case in cases if test_id(case.get("classname", "") + "/" + case.get("name", "")) == selected]
                failed = any(case.find("failure") is not None for case in matching)
                skipped = any(case.find("skipped") is not None for case in cases)
                if len(matching) != 1 or skipped or (defective and (status == 0 or not failed)) or (not defective and (status != 0 or failed)):
                    print(redact(log.read_text(errors="replace")[-8_000:]))
                    raise ValueError(f"Unexpected fault-probe outcome: {label}, defective={defective}")
                evidence.append({"fault": label, "test": selected, "defective": defective,
                                 "exit": status, "assertion_failed": failed})
                print(json.dumps(evidence[-1]), flush=True)
    output = ROOT / "test-results"
    output.mkdir(exist_ok=True)
    (output / "fault-probes.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
