"""Regression checks for validation failures, waivers, transcripts, and reporting."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1] / "vivado/validation"
spec = importlib.util.spec_from_file_location("validator", ROOT / "validate_build.py")
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)

TIMING = """    WNS(ns) TNS(ns) TNS Failing Endpoints TNS Total Endpoints WHS(ns) THS(ns) THS Failing Endpoints THS Total Endpoints WPWS(ns) TPWS(ns) TPWS Failing Endpoints TPWS Total Endpoints
    ------- ------- --- --- ------- ------- --- --- ------- ------- --- ---
    0.005 0.000 0 100 0.010 0.000 0 100 0.000 0.000 0 100
"""
ROUTING = """Design Route Status
 # of routable nets..................... : 100 :
 # of fully routed nets................. : 100 :
 # of nets with routing errors.......... : 0 :
"""
COVERAGE = """check_timing report
1. checking no_clock (0)
------------------------
There are 0 pins.
2. checking unconstrained_internal_endpoints (0)
------------------------------------------------
There are 0 pins.
"""
REPORTS = {"timing": TIMING, "routing": ROUTING, "check_timing": COVERAGE,
           "bus_skew": "Bus Skew Report\nBus Skew Report Summary\nSlack (MET) : 0.001ns\n",
           "cdc": "CDC Report\nID Severity Count Description\nCDC-3 Info 4 Synchronized\n",
           "cdc_waived": "CDC Report\nNo CDC paths found.\n",
           "drc": "Report DRC\nREPORT SUMMARY\nChecks found: 0\n",
           "methodology": "Report Methodology\nREPORT SUMMARY\nChecks found: 0\n",
           "waivers": "No waivers\n"}


class ParserTests(unittest.TestCase):
    def test_hold_and_pulse_width_fail_even_with_positive_setup_slack(self):
        self.assertEqual(v.timing_findings(TIMING), [])
        for before, after, expected in [("0.010 0.000 0", "-0.010 -0.010 1", "hold"),
                                        ("0.000 0.000 0 100\n", "-0.001 -0.001 1 100\n", "pulse_width")]:
            self.assertEqual(v.timing_findings(TIMING.replace(before, after))[0]["id"], expected)

    def test_missing_or_nonfinite_timing_is_not_a_pass(self):
        for text in ["", TIMING.replace("0.005", "NaN"), TIMING.replace("0.005", "N/A")]:
            with self.assertRaises(ValueError):
                v.timing_findings(text)

    def test_bus_skew_failure_and_tied_off_constraints(self):
        self.assertTrue(v.bus_skew_findings(REPORTS["bus_skew"].replace("MET", "VIOLATED").replace("0.001", "-0.001")))
        self.assertFalse(v.bus_skew_findings("Bus Skew Report\nBus Skew Report Summary\nNA 8.000 NA NA\n"))
        with self.assertRaises(ValueError):
            v.bus_skew_findings("")

    def test_routing_errors_and_missing_status_fail(self):
        self.assertFalse(v.routing_findings(ROUTING))
        self.assertTrue(v.routing_findings(ROUTING.replace("fully routed nets................. : 100", "fully routed nets................. : 99")))
        self.assertTrue(v.routing_findings(ROUTING.replace("errors.......... : 0", "errors.......... : 1")))
        with self.assertRaises(ValueError):
            v.routing_findings("Design Route Status")

    def test_cdc_warnings_require_waivers_but_info_does_not(self):
        self.assertFalse(v.rule_findings(REPORTS["cdc"], "cdc"))
        for severity in ["Warning", "Critical"]:
            self.assertEqual(v.rule_findings(REPORTS["cdc"].replace("Info", severity), "cdc")[0]["count"], 4)
        with self.assertRaises(ValueError):
            v.rule_findings("CDC Report", "cdc")

    def test_empty_native_cdc_summary_is_a_valid_zero_result(self):
        self.assertEqual(v.rule_findings("CDC Report\nID  Severity  Count  Description\n--  --------  -----  -----------\n", "cdc"), [])

    def test_critical_drc_and_methodology_findings(self):
        text = "REPORT SUMMARY\n| RULE-1 | Critical Warning | Explanation | 2 |\n| RULE-2 | Warning | Other | 3 |\n"
        for category in ["drc", "methodology"]:
            self.assertEqual(len(v.rule_findings(text, category)), 1)
            self.assertEqual(v.rule_findings(text, category)[0]["count"], 2)

    def test_constraint_coverage_identifies_objects_and_counts(self):
        text = COVERAGE.replace("no_clock (0)", "no_clock (1)").replace("There are 0 pins.", "Some pin:\npath/CCLK", 1)
        result = v.coverage_findings(text)
        self.assertEqual(result[0]["id"], "no_clock")
        self.assertIn("path/CCLK", result[0]["detail"])
        self.assertEqual(result[0]["count"], 1)

    def test_io_coverage_excludes_false_paths_and_output_clocks(self):
        for direction in ("input", "output"):
            with self.subTest(direction=direction):
                port = "input port" if direction == "input" else "port"
                text = (f"1. checking no_{direction}_delay (6)\n------------------------\n"
                        f" There is 1 {port} with no {direction} delay specified. (HIGH)\n\nuntimed_pin\n\n"
                        f" There are 5 {port}s with no {direction} delay but user has a false path constraint. (MEDIUM)\n\nasync_pin\n")
                result = v.coverage_findings(text)
                self.assertEqual(len(result), 1)
                self.assertEqual(result[0]["count"], 1)
                self.assertIn("untimed_pin", result[0]["detail"])
                self.assertNotIn("async_pin", result[0]["detail"])
                covered = text.replace(f"There is 1 {port} with", f"There are 0 {port}s with").replace("There are 5", "There are 6")
                self.assertEqual(v.coverage_findings(covered), [])
        clock_output = ("1. checking no_output_delay (1)\n------------------------\n"
                        "There are 0 ports with no output delay specified.\n"
                        "There is 1 port with no output delay but with a timing clock defined on it or propagating through it\nclock_out\n")
        self.assertEqual(v.coverage_findings(clock_output), [])

    def test_io_coverage_requires_a_valid_missing_delay_breakdown(self):
        for body in ("unrecognized report", "There are 7 input ports with no input delay specified.",
                     "There are 0 input ports with no input delay specified."):
            with self.subTest(body=body), self.assertRaises(ValueError):
                v.coverage_findings("1. checking no_input_delay (6)\n------------------------\n" + body)

    def test_waivers_are_bounded_and_match_build_message_and_source(self):
        waiver = dict(name="known", category="critical_warnings", id="TEST-1", detail="Reviewed warning", source="ip", max_count=1, reason="Reviewed behavior", builds=["design-a"])
        item = v.finding("critical_warnings", "TEST-1", "Reviewed warning", source="ip")
        active, waived, unused = v.apply_waivers([item, item], [waiver], "design-a")
        self.assertEqual((len(active), len(waived), unused), (1, 1, []))
        for changed in [dict(item, source="image"), dict(item, detail="New warning")]:
            self.assertEqual(len(v.apply_waivers([changed], [waiver], "design-a")[0]), 1)
        self.assertEqual(len(v.apply_waivers([item], [waiver], "design-b")[0]), 1)

    def test_invalid_waiver_cannot_hide_timing_or_report_errors(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "waivers.json"
            for category, reason in [("timing", "Reviewed"), ("integrity", "Reviewed"), ("critical_warnings", "")]:
                path.write_text(json.dumps({"waivers": [dict(name="bad", category=category, id="x", detail=".*", source=".*", max_count=1, reason=reason)]}))
                with self.assertRaises(ValueError):
                    v.load_waivers([path])


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.checkpoint = self.root / "routed_design.dcp"
        self.inputs = []
        self.include_transcripts = True
        self.checkpoint.write_bytes(b"checkpoint fixture")
        self.output = self.root / "validation"
        self.build = self.root / "build"
        self.ip = self.root / "ip"
        for path in [*(self.build / f"validation-inputs/{p}.log" for p in ("image", "reg_package", "p4_driver")), self.ip / "validation-inputs/ip.log"]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("BUILD_EXIT_CODE=0\n")
        self.fake = self.root / "vivado"
        self.fake.write_text("#!" + sys.executable + "\nimport pathlib,sys\nout=pathlib.Path(sys.argv[sys.argv.index('-tclargs')+2])\nreports=" + repr(REPORTS) + "\nfor name,text in reports.items(): (out/(name+'.rpt')).write_text(text)\n(out/'report_status.tsv').write_text('checkpoint\\tOK\\n'+''.join(name+'\\tOK\\n' for name in reports))\n")
        self.fake.chmod(0o755)

    def run_validator(self, *extra):
        command = [sys.executable, str(ROOT / "validate_build.py"), "--checkpoint", str(self.checkpoint),
                   "--output-dir", str(self.output), "--name", "design-a", "--vivado", str(self.fake),
                   "--log-root", "products=" + str(self.ip)]
        for path in self.inputs:
            command += ["--input", str(path)]
        for label, path in [(phase, self.build / f"validation-inputs/{phase}.log") for phase in ("image", "reg_package", "p4_driver")] + [("ip", self.ip / "validation-inputs/ip.log")]:
            if self.include_transcripts:
                command += ["--transcript", label + "=" + str(path)]
        result = subprocess.run(command + list(extra), text=True, capture_output=True)
        self.assertTrue((self.output / "junit.xml").is_file(), result.stdout + result.stderr)
        return result, json.loads((self.output / "summary.json").read_text())

    def test_reference_waivers_are_forwarded_without_losing_argument_boundaries(self):
        path = self.root / "waiver with spaces.xdc"
        path.write_text("# scoped waiver\n")
        capture = self.root / "arguments.json"
        self.fake.write_text(self.fake.read_text().replace("import pathlib,sys", "import pathlib,sys,json\npathlib.Path(" + repr(str(capture)) + ").write_text(json.dumps(sys.argv))"))
        result, _ = self.run_validator("--waiver-ref", f"ram_block={path}",
                                       "--waiver-ref", f"fifo_block={path}")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = json.loads(capture.read_text())
        self.assertEqual(args[args.index("-tclargs") + 3:],
                         ["-waiver-ref", "ram_block", str(path), "-waiver-ref", "fifo_block", str(path)])

    def test_missing_reference_waiver_file_fails_before_vivado(self):
        self.fake.chmod(0o644)
        result, summary = self.run_validator("--waiver-ref", f"ram_block={self.root / 'missing.xdc'}")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(f["id"] == "inputs" and "Missing native waiver file" in f["detail"]
                            for f in summary["findings"]))
        self.assertFalse((self.output / "transcript.log").exists())

    def test_complete_build_passes_and_writes_junit(self):
        result, summary = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(summary["passed"])
        self.assertEqual(ET.parse(self.output / "junit.xml").getroot().get("failures"), "0")

    def test_saved_summary_replays_results_without_vivado_or_modifying_artifacts(self):
        for failed in (False, True):
            with self.subTest(failed=failed):
                if failed:
                    (self.build / "validation-inputs/image.log").write_text("CRITICAL WARNING: [TEST-1] warning\nBUILD_EXIT_CODE=0\n")
                original, _ = self.run_validator()
                artifacts = {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.output.iterdir()}
                self.fake.chmod(0o644)  # Replaying must not execute the report tool.
                replay = subprocess.run([sys.executable, str(ROOT / "validate_build.py"), "--summary-only",
                                         "--output-dir", str(self.output)], capture_output=True, text=True)
                self.assertEqual(replay.returncode, original.returncode, replay.stdout + replay.stderr)
                self.assertEqual(replay.stdout, original.stdout)
                self.assertEqual(artifacts, {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.output.iterdir()})
                self.fake.chmod(0o755)

    def test_collection_failure_preserves_category_summary_and_fails_gate(self):
        self.run_validator()
        status = self.root / "collection.exitcode"
        status.write_text("2\n")
        result = subprocess.run([sys.executable, str(ROOT / "validate_build.py"), "--summary-only",
                                 "--output-dir", str(self.output), "--status-file", str(status)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("Validation: FAIL", result.stdout)
        self.assertIn("collection exit status: '2'", result.stdout)
        self.assertIn("timing: PASS", result.stdout)

    def test_missing_malformed_and_inconsistent_saved_results_fail(self):
        self.run_validator()
        path = self.output / "summary.json"
        valid = json.loads(path.read_text())
        for content in ("", "{}", "[]", json.dumps(dict(valid, passed=False)),
                        json.dumps(dict(valid, checked={}))):
            with self.subTest(content=content):
                path.write_text(content)
                result = subprocess.run([sys.executable, str(ROOT / "validate_build.py"), "--summary-only",
                                         "--output-dir", str(self.output)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("Validation: FAIL", result.stdout)
        path.unlink()
        self.assertEqual(v.saved_summary(self.output), 1)

    def test_empty_log_root_cannot_claim_warning_completeness(self):
        self.include_transcripts = False
        result, summary = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertFalse(summary["checked"]["critical_warnings"])
        self.assertTrue(any(f["id"] == "build_log" for f in summary["findings"]))

    def test_message_limit_cannot_hide_additional_critical_warnings(self):
        path = self.build / "validation-inputs/image.log"
        path.write_text("CRITICAL WARNING: [TEST 1-2] first message\nINFO: [Common 17-14] Message 'TEST 1-2' appears 100 times. The message will be suppressed.\nBUILD_EXIT_CODE=0\n")
        result, summary = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertTrue(any(f["id"] == "suppressed_messages" for f in summary["findings"]))

    def test_cached_ip_critical_warning_is_checked_but_backup_is_ignored(self):
        folder = self.ip / "arbitrary/generated/component"
        folder.mkdir(parents=True)
        (folder / "vivado_123.backup.log").write_text("CRITICAL WARNING: [OLD-1] Old build\n")
        self.assertEqual(self.run_validator()[0].returncode, 0)
        (folder / "component.synth.log").write_text("CRITICAL WARNING: [LIVE-1] Active cached product warning\n")
        result, summary = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([f["id"] for f in summary["findings"]], ["LIVE-1"])

    def test_early_phase_critical_warning_is_retained(self):
        (self.build / "validation-inputs/image.log").write_text("CRITICAL WARNING: [SYNTH-1] Early phase\nLater export succeeded\nBUILD_EXIT_CODE=0\n")
        result, summary = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(summary["findings"][0]["id"], "SYNTH-1")

    def test_missing_checkpoint_and_missing_transcript_fail_with_junit(self):
        self.checkpoint.unlink()
        (self.ip / "validation-inputs/ip.log").unlink()
        result, summary = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(f["id"] == "inputs" for f in summary["findings"]))
        self.assertTrue(any(f["id"] == "build_log" for f in summary["findings"]))
        self.assertFalse(summary["checked"]["timing"])
        self.assertEqual(len(ET.parse(self.output / "junit.xml").findall("testcase[@name='timing']/skipped")), 1)

    def test_incomplete_reports_cannot_reuse_previous_success(self):
        self.assertEqual(self.run_validator()[0].returncode, 0)
        self.fake.write_text("#!" + sys.executable + "\n")
        result, summary = self.run_validator()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(summary["passed"])
        self.assertFalse((self.output / "timing.rpt").exists())

    def test_newer_implementation_checkpoint_is_rejected(self):
        dependency = self.root / "required_input.dcp"
        dependency.write_bytes(b"newer implementation")
        self.inputs = [dependency]
        os.utime(self.checkpoint, (1, 1))
        result, summary = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertTrue(any(f["id"] == "stale_checkpoint" for f in summary["findings"]))

    def test_malformed_waiver_documents_are_rejected(self):
        path = self.root / "bad.json"
        for document in [[], {"waivers": [1]}, {"waivers": [dict(name="x", category="critical_warnings", id="X", detail="[", source=".*", max_count=1, reason="reviewed")]}]:
            path.write_text(json.dumps(document))
            with self.assertRaises(ValueError):
                v.load_waivers([path])

    def test_logged_command_propagates_failure_and_preserves_output(self):
        path = self.root / "logged/phase.log"
        result = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / "run_logged.py"), "--log", str(path), "--", sys.executable, "-c", "import sys; print('CRITICAL WARNING: [X-1] text'); sys.exit(7)"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 7)
        self.assertIn("CRITICAL WARNING", result.stdout)
        self.assertTrue(path.read_text().endswith("BUILD_EXIT_CODE=7\n"))


if __name__ == "__main__":
    unittest.main()
