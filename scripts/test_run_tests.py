from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import run_tests as gate


class GateTests(unittest.TestCase):
    def check(self, xml, discovered=None, required=None):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "test.xml"
            report.write_text(xml)
            return gate.validate([report], {"JarvisTests.Suite/example"} if discovered is None else discovered,
                                 {"JarvisTests.Suite/example"} if required is None else required)

    def test_valid_result(self):
        self.assertEqual(self.check('<testsuites><testsuite tests="1"><testcase classname="JarvisTests.Suite" name="example()"/></testsuite></testsuites>'), 1)

    def test_zero_missing_malformed_and_skipped_results_fail(self):
        for xml in ('<testsuites/>', '<broken',
                    '<testsuite skipped="1"><testcase classname="JarvisTests.Suite" name="example()"/></testsuite>',
                    '<testsuite><testcase classname="JarvisTests.Suite" name="example()"><skipped/></testcase></testsuite>',
                    '<testsuite><testcase classname="JarvisTests.Suite" name="example()"><failure/></testcase></testsuite>',
                    '<testsuite errors="1"/>'):
            with self.subTest(xml=xml), self.assertRaises((ValueError, gate.ET.ParseError)):
                self.check(xml)
        with self.assertRaises(ValueError):
            gate.validate([], {"example"}, set())

    def test_partial_selection_or_removed_critical_test_fails(self):
        xml = '<testsuite><testcase classname="JarvisTests.Suite" name="example()"/></testsuite>'
        for discovered, required in ((set(), set()), ({"JarvisTests.Suite/other"}, set()),
                                      ({"JarvisTests.Suite/example"}, {"JarvisTests.Suite/removed"})):
            with self.subTest(discovered=discovered, required=required), self.assertRaises(ValueError):
                self.check(xml, discovered, required)

    def test_process_failure_and_timeout_are_not_success(self):
        import sys
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "process.log"
            self.assertEqual(gate.run([sys.executable, "-c", "raise SystemExit(7)"], log, 5), 7)
            self.assertEqual(gate.run([sys.executable, "-c", "import os, signal; os.kill(os.getpid(), signal.SIGTERM)"], log, 5), -15)
            with self.assertRaisesRegex(ValueError, "time limit"):
                gate.run([sys.executable, "-c", "import time; time.sleep(30)"], log, 0.1)

    def test_failure_artifacts_are_bounded_and_redacted(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "output.log"
            log.write_text("x" * (gate.LIMIT * 2) + f"\n{Path.home()}/private.txt token=synthetic-secret\n")
            result = gate.tail(log)
            self.assertLessEqual(len(result), gate.LIMIT)
            self.assertNotIn(str(Path.home()), result)
            self.assertNotIn("synthetic-secret", result)

    def test_main_never_trusts_green_xml_after_a_failed_process(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "scripts/critical-tests.json").write_text('["JarvisTests.Suite/example"]')

            def fake_run(command, log, timeout):
                log.write_text("synthetic diagnostic")
                report = Path(command[command.index("--xunit-output") + 1])
                report.write_text('<testsuite><testcase classname="JarvisTests.Suite" name="example()"/></testsuite>')
                return 7

            with patch.object(gate, "ROOT", root), patch.object(gate, "run", fake_run), \
                    patch("sys.argv", ["run_tests.py", "--output", str(root / "results")]), \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(gate.main(), 1)
            summary = json.loads((root / "results/summary.json").read_text())
            self.assertFalse(summary["passed"])
            self.assertEqual(summary["process_exit"], 7)


if __name__ == "__main__":
    unittest.main()
import contextlib
import io
import json
