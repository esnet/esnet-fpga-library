"""Console filtering must never remove evidence from the full transcript."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "run_logged.py"
PROFILE = ROOT / "vivado/console_filters/vivado-progress.json"


class LoggedConsoleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="logged-console-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.log = self.root / "build/output.log"
        self.env = os.environ.copy()
        self.env.pop("RUN_LOGGED_CONSOLE_FILTER", None)

    def command(self, source, *options):
        return [sys.executable, str(SCRIPT), "--log", str(self.log), *map(str, options),
                "--", sys.executable, "-u", "-c", source]

    def child(self, source, *options, env=None):
        return subprocess.run(self.command(source, *options), env=env or self.env,
                              capture_output=True, text=True, timeout=10)

    def filtered(self, source, *options, env=None):
        return self.child(source, "--console-filter", PROFILE, "--heartbeat", "0", *options, env=env)

    def test_default_console_and_exit_status_are_unchanged(self):
        for status in (0, 7):
            result = self.child(f"import sys; print('normal output'); print('stderr output',file=sys.stderr); print('partial',end='');sys.exit({status})")
            self.assertEqual(result.returncode, status, result.stderr)
            self.assertEqual(result.stdout, "normal output\nstderr output\npartial")
            self.assertEqual(self.log.read_text(), f"normal output\nstderr output\npartial\nBUILD_EXIT_CODE={status}\n")

    def test_filtered_and_unfiltered_transcripts_are_identical(self):
        source = "import sys;print('Starting synth_design'); print('INFO: routine detail');print('CRITICAL WARNING: [TEST-1] important');print('  context');print('stderr detail',file=sys.stderr);print('partial',end='')"
        self.assertEqual(self.child(source).returncode, 0)
        complete = self.log.read_bytes()
        result = self.filtered(source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_bytes(), complete)
        self.assertIn("Starting synth_design", result.stdout)
        self.assertIn("CRITICAL WARNING", result.stdout)
        self.assertIn("  context", result.stdout)
        self.assertNotIn("routine detail", result.stdout)
        self.assertNotIn("stderr detail", result.stdout)
        self.assertNotIn("[run_logged]", self.log.read_text())

    def test_vivado_phase_and_timing_summary_milestones_remain_visible(self):
        lines = ["Non-project build: running route for 'design' ...", "# route_design -directive Explore",
                 "Phase 2.1 Route Optimization", "Finished Timing Optimization", "Executing implementation using strategy: Explore",
                 "    WNS(ns) TNS(ns) WHS(ns) WPWS(ns)", "    0.005 0.000 0 100 0.010 0.000 0 100 0.000 0.000 0 100",
                 "All user specified timing constraints are met.", "Phase 'route' complete."]
        result = self.filtered("print(" + repr("\n".join(lines)) + ")")
        self.assertEqual(result.returncode, 0, result.stderr)
        for line in lines:
            self.assertIn(line, result.stdout)

    def test_per_cell_constraint_loading_chatter_is_hidden(self):
        line = "Finished Parsing XDC File [very/long/ip/constraint/path.xdc] for cell nested/cell"
        result = self.filtered("print(" + repr(line) + ")")
        self.assertNotIn(line, result.stdout)
        self.assertIn(line, self.log.read_text())

    def test_inline_timing_summaries_remain_visible_without_per_net_detail(self):
        lines = [
            "INFO: [Physopt 32-619] Estimated Timing Summary | WNS=-0.209 | TNS=-27.778 |",
            "INFO: [Place 30-746] Post Placement Timing Summary WNS=-0.040. For the most accurate timing information please run report_timing.",
            "INFO: [Place 46-19] Post Replication Timing Summary WNS=0.501. For the most accurate timing information please run report_timing.",
            "INFO: [Route 35-416] Intermediate Timing Summary | WNS=-0.049 | TNS=-0.672 | WHS=N/A | THS=N/A |",
            "INFO: [Route 35-57] Estimated Timing Summary | WNS=0.003 | TNS=0.000 | WHS=0.005 | THS=0.000 |",
            "INFO: [Physopt 32-669] Post Physical Optimization Timing Summary | WNS=-0.227 | TNS=-356.384 | WHS=0.000 | THS=0.000 |",
            "Design Timing Summary",
            "Timing constraints are not met.",
        ]
        detail = "INFO: [Physopt 32-952] Improved path group WNS = -0.098. Path group: clk. Processed net: nested/cell/net."
        result = self.filtered("print(" + repr("\n".join(lines + [detail])) + ")")
        self.assertEqual(result.returncode, 0, result.stderr)
        for line in lines:
            self.assertIn(line, result.stdout)
        self.assertNotIn(detail, result.stdout)
        self.assertIn(detail, self.log.read_text())

    def test_custom_build_banner_text_remains_visible(self):
        lines = [
            "Creating OOC project output/proj.xpr ...",
            "Creating build project (core__stub__build) ...",
            "Compiling synthesis library 'core__stub__build' ...",
            "Compiling simulation library 'axi4l__rtl' ...",
            "Synthesizing core ...",
            "Synthesizing IP xilinx_qdma_ecc ...",
            "Synthesize BD (xilinx__alveo__versal__bd) ...",
            "Synthesis for core is up to date.",
            "Synthesis products for xilinx_qdma_ecc are up to date.",
            "Optimizing core ...",
            "Optimization of core is up to date.",
            "Running route_design on core ...",
            "Running route_design for 'core' ...",
            "Generate IP simulation output products (xilinx__qdma__ip) ...",
            "Generating XCI for xilinx_qdma_ecc ...",
            "Generating bitstream for core ...",
            "Generating device image for core ...",
            "Generating flash image for core ...",
            "Pre-generating BD output products...",
            "Elaborating top-level regio IR: output.yaml",
            "Linking design: top=core part=part",
            "Building core regio for core.stub.regio ...",
            "Reset IP output products (xilinx__qdma__ip) ...",
        ]
        separator = "----------------------------------------------------------"
        result = self.filtered("print(" + repr("\n".join([separator, *lines])) + ")")
        self.assertEqual(result.returncode, 0, result.stderr)
        for line in lines:
            self.assertIn(line, result.stdout)
        self.assertNotIn(separator, result.stdout)
        self.assertIn(separator, self.log.read_text())

    def test_license_status_and_repeated_license_warnings_remain_visible(self):
        lines = [
            "Attempting to get a license for feature 'Synthesis' and/or device 'xcv80'",
            "INFO: [Common 17-349] Got license for feature 'Synthesis' and/or device 'xcv80'",
            "INFO: [Common 17-83] Releasing license: Synthesis",
            "INFO: [IP_Flow 19-1] IP 'example' is licensed for implementation.",
            "License keys found for xilinx.com:ip:example:1.0: example_feature.",
            "No license file needed for xilinx.com:ip:clk_wiz:6.0.",
        ]
        warnings = [f"WARNING: [License 1-1] License unavailable for IP instance {i}" for i in range(5)]
        result = self.filtered("print(" + repr("\n".join(lines + warnings)) + ")")
        self.assertEqual(result.returncode, 0, result.stderr)
        for line in lines + warnings:
            self.assertIn(line, result.stdout)
        self.assertNotIn("Further warnings", result.stdout)
        self.assertEqual(self.log.read_text(), "\n".join(lines + warnings) + "\n\nBUILD_EXIT_CODE=0\n")

    def test_warning_limit_counts_messages_and_suppresses_their_context(self):
        source = "for i in range(8):\n print(f'WARNING: [RULE-1] occurrence {i}')\n print(f'  details {i}')\n"
        result = self.filtered(source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("WARNING: [RULE-1]"), 3)
        self.assertIn("details 2", result.stdout)
        self.assertNotIn("details 3", result.stdout)
        self.assertIn("8 occurrences; 5 omitted", result.stdout)
        self.assertEqual(self.log.read_text().count("WARNING: [RULE-1]"), 8)
        self.assertIn("details 7", self.log.read_text())

    def test_distinct_warning_ids_have_independent_limits(self):
        result = self.filtered("for i in range(5):\n print('WARNING: [RULE-A] a')\n print('WARNING: [RULE-B] b')\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("WARNING: [RULE-A]"), 3)
        self.assertEqual(result.stdout.count("WARNING: [RULE-B]"), 3)
        self.assertEqual(result.stdout.count("5 occurrences; 2 omitted"), 2)

    def test_critical_warnings_errors_and_unidentified_warnings_are_not_limited(self):
        result = self.filtered("for i in range(7):\n print('CRITICAL WARNING: [RULE-1] critical')\n print('ERROR: [RULE-2] error')\n print('WARNING: no message ID')\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("critical\n"), 7)
        self.assertEqual(result.stdout.count("error\n"), 7)
        self.assertEqual(result.stdout.count("WARNING: no message ID"), 7)

    def test_diagnostic_context_ends_at_an_unrelated_message(self):
        result = self.filtered("print('ERROR: [X] important');print('  relevant');print('INFO: routine');print('  unrelated')")
        self.assertIn("relevant", result.stdout)
        self.assertNotIn("unrelated", result.stdout)

    def test_ansi_colors_do_not_prevent_diagnostic_matching(self):
        line = "\x1b[31mCRITICAL WARNING: [COLOR-1] colored\x1b[0m"
        result = self.filtered("print(" + repr(line) + ")")
        self.assertIn(line, result.stdout)
        self.assertIn(line, self.log.read_text())

    def test_environment_filter_and_explicit_override(self):
        env = dict(self.env, RUN_LOGGED_CONSOLE_FILTER=str(PROFILE))
        result = self.child("print('INFO: routine')", env=env)
        self.assertNotIn("INFO: routine", result.stdout)
        custom = self.root / "custom.json"
        custom.write_text(json.dumps({"progress": ["^INFO:"], "diagnostics": []}))
        result = self.child("print('INFO: routine')", "--console-filter", custom, env=env)
        self.assertIn("INFO: routine", result.stdout)

    def test_custom_profile_is_not_tied_to_vivado(self):
        custom = self.root / "generic.json"
        custom.write_text(json.dumps({"progress": ["^STEP "], "diagnostics": ["^ALERT "],
                                      "warning": {"pattern": r"^NOTICE (?P<id>\w+):", "limit": 1}}))
        result = self.child("print('STEP compile');print('unimportant');print('NOTICE ABC: one');print('NOTICE ABC: two');print('ALERT broken')", "--console-filter", custom)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("STEP compile", result.stdout)
        self.assertIn("ALERT broken", result.stdout)
        self.assertNotIn("unimportant", result.stdout)
        self.assertNotIn("NOTICE ABC: two", result.stdout)
        self.assertIn("2 occurrences; 1 omitted", result.stdout)

    def test_heartbeat_while_child_is_silent(self):
        result = self.filtered("import time;print('Starting route_design');time.sleep(0.3)", "--heartbeat", "0.05")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Still running; elapsed", result.stdout)
        self.assertIn("last progress: Starting route_design", result.stdout)
        self.assertNotIn("Still running", self.log.read_text())

    def test_heartbeat_while_filtered_output_is_busy(self):
        result = self.filtered("import time\nprint('Starting synth_design')\nfor i in range(150):\n print('INFO: hidden activity');time.sleep(0.002)\n", "--heartbeat", "0.05")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Still running", result.stdout)
        self.assertNotIn("INFO: hidden activity", result.stdout)
        self.assertEqual(self.log.read_text().count("hidden activity"), 150)

    def test_heartbeat_continues_after_stdout_closes(self):
        result = self.filtered("import os,time;print('Starting route_design');os.close(1);os.close(2);time.sleep(0.3);os._exit(0)", "--heartbeat", "0.05")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Still running", result.stdout)

    def test_transcript_is_flushed_before_the_child_finishes(self):
        ready, release = self.root / "ready", self.root / "release"
        source = f"import pathlib,time;print('INFO: hidden live output');pathlib.Path({str(ready)!r}).touch()\nwhile not pathlib.Path({str(release)!r}).exists():time.sleep(0.01)\n"
        process = subprocess.Popen(self.command(source, "--console-filter", PROFILE, "--heartbeat", "0"),
                                   env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if ready.exists() and self.log.exists() and "hidden live output" in self.log.read_text():
                    break
                time.sleep(0.02)
            else:
                self.fail("Transcript did not flush while the child was running")
            self.assertIsNone(process.poll())
            self.assertNotIn("BUILD_EXIT_CODE=", self.log.read_text())
        finally:
            release.touch()
            stdout, stderr = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, stderr)
        self.assertNotIn("hidden live output", stdout)

    def test_unknown_failure_replays_a_bounded_unfiltered_tail(self):
        result = self.filtered("import sys\nfor i in range(10):print(f'hidden detail {i}')\nprint('unexpected tool failure',file=sys.stderr);sys.exit(7)", "--failure-tail", "3")
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertIn("last 3 transcript lines (unfiltered)", result.stdout)
        self.assertIn("hidden detail 8", result.stdout)
        self.assertIn("unexpected tool failure", result.stdout)
        self.assertNotIn("hidden detail 7", result.stdout)
        self.assertIn("hidden detail 0", self.log.read_text())
        self.assertTrue(self.log.read_text().endswith("BUILD_EXIT_CODE=7\n"))

    def test_failure_tail_can_be_disabled(self):
        result = self.filtered("import sys;print('unknown failure text');sys.exit(3)", "--failure-tail", "0")
        self.assertEqual(result.returncode, 3)
        self.assertNotIn("unknown failure text", result.stdout)
        self.assertIn("exit code 3", result.stdout)
        self.assertIn("unknown failure text", self.log.read_text())

    def test_partial_visible_line_does_not_absorb_summary(self):
        result = self.filtered("print('Starting route_design',end='')")
        self.assertIn("Starting route_design\n[run_logged] Command finished", result.stdout)

    def test_signal_exit_status_is_preserved(self):
        result = self.filtered("import os,signal;os.kill(os.getpid(),signal.SIGTERM)")
        self.assertEqual(result.returncode, 128 + signal.SIGTERM)
        self.assertTrue(self.log.read_text().endswith(f"BUILD_EXIT_CODE={-signal.SIGTERM}\n"))

    def test_launch_failure_is_logged_with_nonzero_status(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--log", str(self.log), "--console-filter", str(PROFILE),
                                 "--", str(self.root / "does-not-exist")], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 127)
        self.assertIn("could not start", result.stdout)
        self.assertIn("ERROR:", self.log.read_text())
        self.assertTrue(self.log.read_text().endswith("BUILD_EXIT_CODE=127\n"))

    def test_bad_profiles_fail_before_launch_or_overwriting_an_existing_log(self):
        bad = self.root / "bad.json"
        self.log.parent.mkdir(parents=True)
        self.log.write_text("previous transcript")
        documents = [[], {}, {"progress": "x", "diagnostics": []}, {"progress": ["["], "diagnostics": []},
                     {"progress": [], "diagnostics": [], "unknown": 1},
                     {"progress": [], "diagnostics": [], "warning": {"pattern": "WARNING", "limit": 3}},
                     {"progress": [], "diagnostics": [], "warning": {"pattern": "(?P<id>x)", "limit": True}}]
        for document in documents:
            bad.write_text(json.dumps(document))
            result = self.child("raise RuntimeError('child must not run')", "--console-filter", bad)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("Invalid console filter", result.stderr)
            self.assertEqual(self.log.read_text(), "previous transcript")

    def test_bad_numeric_options_are_rejected(self):
        for option, value in [("--heartbeat", "-1"), ("--heartbeat", "nan"), ("--heartbeat", "inf"), ("--failure-tail", "-1")]:
            result = self.filtered("print('must not run')", option, value)
            self.assertEqual(result.returncode, 2, result.stderr)

    def test_new_run_replaces_the_old_transcript(self):
        self.assertEqual(self.filtered("print('old output')").returncode, 0)
        self.assertEqual(self.filtered("print('new output')").returncode, 0)
        self.assertNotIn("old output", self.log.read_text())
        self.assertEqual(self.log.read_text().count("BUILD_EXIT_CODE="), 1)


if __name__ == "__main__":
    unittest.main()
