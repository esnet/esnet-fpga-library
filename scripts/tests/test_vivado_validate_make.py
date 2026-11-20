"""Exercise the reusable Make interface without any enclosing project config."""
import json
import os
from pathlib import Path
import subprocess
import unittest

import test_validate_build

MAKEFILE = Path(__file__).resolve().parents[1] / "Makefiles/vivado_validate.mk"


class GenericValidationMakeTests(unittest.TestCase):
    def setUp(self):
        test_validate_build.RunnerTests.setUp(self)
        self.waiver_dir = self.root / "reviewed-exceptions"
        self.waiver_dir.mkdir()
        self.build_log = self.build / "validation-inputs/image.log"
        self.makefile = self.root / "Makefile"
        self.makefile.write_text(f'''
VALIDATION_NAME := build-a
VALIDATION_CHECKPOINT := {self.checkpoint}
VALIDATION_DIR := {self.output}
VALIDATION_VIVADO := {self.fake}
VALIDATION_TRANSCRIPTS := synthesis={self.build_log}
VALIDATION_WAIVER_DIRS := {self.waiver_dir}
include {MAKEFILE}
''')

    def run_make(self, *args):
        env = os.environ.copy()
        for key in ("MAKEFLAGS", "MFLAGS", "MAKELEVEL", "BOARD", "SMARTNIC_ROOT", "LIB_ROOT", "SCRIPTS_ROOT"):
            env.pop(key, None)
        result = subprocess.run(["make", "-s", "validate", *args], cwd=self.root, env=env, text=True, capture_output=True)
        self.assertTrue((self.output / "junit.xml").is_file(), result.stdout + result.stderr)
        return result, json.loads((self.output / "summary.json").read_text())

    def test_standalone_make_uses_explicit_checkpoint_and_log_paths(self):
        result, summary = self.run_make()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(summary["name"], "build-a")
        self.assertNotIn("board", summary)
        self.assertEqual(summary["checkpoint"], str(self.checkpoint))

    def test_component_defaults_select_each_build_phase_log(self):
        product = self.root / "component-output"
        product.mkdir()
        for phase in ("synth", "route_opt"):
            (product / f"component.{phase}.log").write_text("INFO: [TEST-1] complete\n")
        self.makefile.write_text(f'''
TOP := component
COMPONENT_OUT_PATH := {product}
BUILD_STAGES := synth route_opt
VALIDATION_CHECKPOINT := {self.checkpoint}
VALIDATION_DIR := {self.output}
VALIDATION_VIVADO := {self.fake}
include {MAKEFILE}
''')
        result, summary = self.run_make()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(summary["name"], "component")
        (product / "component.synth.log").unlink()
        result, summary = self.run_make()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(f["id"] == "build_log" for f in summary["findings"]))

    def test_build_name_selects_its_own_waivers(self):
        self.build_log.write_text("CRITICAL WARNING: [RULE-1] Reviewed condition\nBUILD_EXIT_CODE=0\n")
        waiver = dict(name="reviewed", category="critical_warnings", id="RULE-1", source="synthesis",
                      detail="Reviewed condition", max_count=1, reason="Reviewed for this build", builds=["build-a"])
        (self.waiver_dir / "common.json").write_text('{"waivers": []}')
        (self.waiver_dir / "build-a.json").write_text(json.dumps({"waivers": [waiver]}))
        result, summary = self.run_make()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(summary["waived"]), 1)
        result, summary = self.run_make("VALIDATION_NAME=build-b")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(f["id"] == "RULE-1" for f in summary["findings"]))

    def test_native_waiver_discovery_and_explicit_override(self):
        for name in ("common.xdc", "build-a.xdc", "build-b.xdc"):
            (self.waiver_dir / name).write_text("# reviewed native waivers\n")
        capture = self.root / "arguments.json"
        self.fake.write_text(self.fake.read_text().replace("import pathlib,sys", "import pathlib,sys,json\npathlib.Path(" + repr(str(capture)) + ").write_text(json.dumps(sys.argv))"))
        self.assertEqual(self.run_make()[0].returncode, 0)
        args = json.loads(capture.read_text())
        self.assertEqual(args[args.index("-tclargs") + 3:], [str(self.waiver_dir / "common.xdc"), str(self.waiver_dir / "build-a.xdc")])
        self.assertEqual(self.run_make(f"VALIDATION_WAIVER_TCL={self.waiver_dir}/build-b.xdc")[0].returncode, 0)
        args = json.loads(capture.read_text())
        self.assertEqual(args[args.index("-tclargs") + 3:], [str(self.waiver_dir / "build-b.xdc")])

    def test_reference_scoped_waivers_can_be_combined_with_global_waivers(self):
        global_path = self.waiver_dir / "common.xdc"
        scoped_path = self.waiver_dir / "ram.xdc"
        global_path.write_text("# global waivers\n")
        scoped_path.write_text("# reference-scoped waivers\n")
        capture = self.root / "arguments.json"
        self.fake.write_text(self.fake.read_text().replace("import pathlib,sys", "import pathlib,sys,json\npathlib.Path(" + repr(str(capture)) + ").write_text(json.dumps(sys.argv))"))
        result, _ = self.run_make(f"VALIDATION_WAIVER_REFS=ram_block={scoped_path} fifo_block={scoped_path}")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = json.loads(capture.read_text())
        self.assertEqual(args[args.index("-tclargs") + 3:],
                         [str(global_path), "-waiver-ref", "ram_block", str(scoped_path),
                          "-waiver-ref", "fifo_block", str(scoped_path)])

    def test_make_forwards_named_evidence_and_configuration_failures_remain_visible(self):
        self.build_log.write_text("CRITICAL WARNING: [RULE-1] Reviewed condition\nBUILD_EXIT_CODE=0\n")
        artifact = self.root / "configuration.txt"
        artifact.write_text("OUTPUT_REG=1")
        age = self.checkpoint.stat().st_mtime_ns - 1
        os.utime(artifact, ns=(age, age))
        waiver = dict(name="guarded", category="critical_warnings", id="RULE-1", source="synthesis",
                      detail="Reviewed condition", max_count=1, reason="Output register present",
                      evidence=[dict(input="configuration", pattern="OUTPUT_REG=1")])
        (self.waiver_dir / "common.json").write_text(json.dumps({"waivers": [waiver]}))
        result, summary = self.run_make(f"VALIDATION_WAIVER_INPUTS=configuration={artifact}")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(summary["waiver_evidence"][0]["passed"])
        result, summary = self.run_make()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(summary["waived"])
        self.assertTrue(any(f["id"] == "waiver_evidence" for f in summary["findings"]))

    def test_missing_explicit_freshness_input_is_a_failure(self):
        result, summary = self.run_make(f"VALIDATION_INPUTS={self.root}/missing.dcp")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(f["id"] == "missing_input" for f in summary["findings"]))


if __name__ == "__main__":
    unittest.main()
