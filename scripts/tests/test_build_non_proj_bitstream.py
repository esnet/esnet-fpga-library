"""Exercise non-project export hooks and incremental artifact recovery without Vivado.

Run with: python3 -B -m unittest discover -s scripts/tests
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]
RUNNER = SCRIPTS / "vivado/build_non_proj.tcl"
SCRIPT = Path(__file__).resolve()


def mock_vivado(root, args):
    root = Path(root)
    phase = args[args.index("-tclargs") + 1]
    log = root / "out" / args[args.index("-log") + 1]
    log.write_text(f"phase={phase}\n")
    with (root / "events").open("a") as stream:
        stream.write(phase + "\n")
    out = root / "out"
    if phase == "route_opt":
        (out / "shell.route_opt.dcp").write_text("routed checkpoint")
    else:
        for suffix in ("bit", "bin", "ltx"):
            if suffix != os.environ.get("OMIT_ARTIFACT"):
                (out / f"shell.{suffix}").write_text(suffix)
        if os.environ.get("FAIL_EXPORT") == "1":
            raise SystemExit("simulated post-export hook failure")


class ExportRunnerTest(unittest.TestCase):
    def run_phase(self, phase, fail=None, ids=("0x1234", "0x5678")):
        temporary = tempfile.TemporaryDirectory(prefix="nonproj-export-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / "shell.route_opt.dcp").write_text("checkpoint")
        pre = root / f"write_{phase}.pre.tcl"
        pre.write_text('''record pre
if {$::NP_TOP ne "shell" || $::NP_USERID ne "@USERID@" ||
    $::NP_OUT_DIR ne [file dirname [info script]] ||
    $::NP_TOP_DCP ne "input.dcp"} {error "Missing export hook context"}
'''.replace("@USERID@", ids[0] if ids[0] is not None else ""))
        post = root / f"write_{phase}.post.tcl"
        post.write_text('''record post
if {![file exists $::NP_OUT_DIR/${::NP_TOP}.ltx]} {error "Missing probes before post hook"}
''')
        if fail:
            with {"pre": pre, "post": post}[fail].open("a") as stream:
                stream.write('error "simulated hook failure"\n')
        unrelated = root / "write_other.pre.tcl"
        unrelated.write_text('error "Unrelated hook executed"\n')
        driver = root / "driver.tcl"
        driver.write_text(r'''
set argv [list @PHASE@ shell -out_dir {@ROOT@} -top_dcp input.dcp @ID_ARGS@ \
    -hook_tcl {@PRE@} -hook_tcl {@POST@} -hook_tcl {@UNRELATED@}]
set argc [llength $argv]
set events_file {@ROOT@/events}
set properties [dict create BITSTREAM.CONFIG.USERID existing-userid BITSTREAM.CONFIG.USR_ACCESS existing-access]
proc current_design {} {return design}
proc set_property {property value object} {
    if {$object ne "design" || ![dict exists $::properties $property]} {
        error "Unexpected bitstream property: $property"
    }
    dict set ::properties $property $value
}
proc record_ids {} {
    set stream [open {@ROOT@/shell.ids} w]
    puts $stream [list [dict get $::properties BITSTREAM.CONFIG.USERID] \
        [dict get $::properties BITSTREAM.CONFIG.USR_ACCESS]]
    close $stream
}
proc record {event} {
    set stream [open $::events_file a]
    puts $stream $event
    close $stream
}
proc write_file {path} {
    set stream [open $path w]
    puts $stream artifact
    close $stream
}
proc open_checkpoint {path} {
    if {![file exists $path]} {error "Wrong input checkpoint: $path"}
    record open
}
proc write_bitstream {args} {
    if {[lrange $args 0 end-1] ne {-force -bin_file}} {error "Missing bitstream options"}
    record bitstream
    record_ids
    set bitfile [lindex $args end]
    write_file $bitfile
    write_file [file rootname $bitfile].bin
}
proc write_device_image {args} {
    record device_image
    record_ids
    write_file [lindex $args end]
}
proc write_debug_probes {args} {
    record probes
    write_file [lindex $args end]
}
source {@RUNNER@}
'''.replace("@ID_ARGS@", " ".join(
                f"{flag} {{{value}}}" for flag, value in zip(("-userid", "-usr_access"), ids)
                if value is not None))
            .replace("@PHASE@", phase).replace("@ROOT@", str(root))
            .replace("@PRE@", str(pre)).replace("@POST@", str(post))
            .replace("@UNRELATED@", str(unrelated)).replace("@RUNNER@", str(RUNNER)))
        result = subprocess.run(["tclsh", str(driver)], capture_output=True, text=True)
        events = (root / "events").read_text().splitlines()
        return root, result, events

    def test_bitstream_hooks_and_outputs(self):
        root, result, events = self.run_phase("bitstream")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(events, ["open", "pre", "bitstream", "probes", "post"])
        for suffix in ("bit", "bin", "ltx"):
            self.assertTrue((root / f"shell.{suffix}").is_file())
        self.assertEqual((root / "shell.ids").read_text().split(), ["0x1234", "0x5678"])

    def test_bitstream_ids_preserve_omitted_properties(self):
        for ids in ((None, None), ("0", "0"), ("0x1234", None), (None, "0x5678")):
            with self.subTest(ids=ids):
                root, result, _ = self.run_phase("bitstream", ids=ids)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                expected = [value if value is not None else previous for value, previous in
                            zip(ids, ("existing-userid", "existing-access"))]
                self.assertEqual((root / "shell.ids").read_text().split(), expected)

    def test_device_image_hooks_and_outputs(self):
        root, result, events = self.run_phase("device_image")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(events, ["open", "pre", "device_image", "probes", "post"])
        self.assertTrue((root / "shell.pdi").is_file())
        self.assertTrue((root / "shell.ltx").is_file())
        self.assertFalse((root / "shell.bit").exists())
        self.assertEqual((root / "shell.ids").read_text().split(), ["existing-userid", "existing-access"])

    def test_hook_failures_propagate(self):
        for phase in ("bitstream", "device_image"):
            for hook in ("pre", "post"):
                with self.subTest(phase=phase, hook=hook):
                    _, result, events = self.run_phase(phase, fail=hook)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("simulated hook failure", result.stderr)
                    if hook == "pre":
                        self.assertEqual(events, ["open", "pre"])


class MakeFixture:
    def __init__(self, root, jobs=1):
        self.root = Path(root)
        self.jobs = jobs
        self.out = self.root / "out"
        self.hook = self.root / "export.post.tcl"
        self.hook.write_text("hook")
        (self.root / "input.dcp").write_text("input")
        toolchain = self.root / "toolchain"
        (toolchain / "Makefiles").mkdir(parents=True)
        (toolchain / "vivado").mkdir()
        for name in ("vivado_build_non_proj.mk", "vivado_base.mk", "vivado_validate.mk"):
            shutil.copyfile(SCRIPTS / "Makefiles" / name, toolchain / "Makefiles" / name)
        shutil.copyfile(RUNNER, toolchain / "vivado/build_non_proj.tcl")
        (toolchain / "Makefiles/vivado_compile.mk").write_text(
            '_compile_synth:\n\t@echo pre >> $(TEST_ROOT)/events\n'
        )
        (self.root / "Makefile").write_text(f'''
TEST_ROOT := {self.root}
SCRIPTS_ROOT := {toolchain}
COMPONENT_OUT_PATH := $(TEST_ROOT)/out
TOP := shell
BUILD_STAGES := route_opt bitstream
STAGE_DEPS := $(TEST_ROOT)/input.dcp
override VIVADO_NP_CMD = {sys.executable} {SCRIPT} --mock $(TEST_ROOT)
export FAIL_EXPORT OMIT_ARTIFACT
include {toolchain}/Makefiles/vivado_build_non_proj.mk
$(COMPONENT_OUT_PATH)/.done/bitstream: $(TEST_ROOT)/export.post.tcl
''')

    def run(self, *goals, success=True, **variables):
        events = self.root / "events"
        events.unlink(missing_ok=True)
        env = os.environ.copy()
        for name in ("MAKEFLAGS", "MFLAGS", "MAKELEVEL"):
            env.pop(name, None)
        result = subprocess.run(
            ["make", "--no-print-directory", f"-j{self.jobs}",
             *(goals or ("_np_bitstream",)),
             *(f"{name}={value}" for name, value in variables.items())],
            cwd=self.root, env=env, capture_output=True, text=True, timeout=30,
        )
        if (result.returncode == 0) != success:
            raise AssertionError(result.stdout + result.stderr)
        self.events = events.read_text().splitlines()
        return result.stdout + result.stderr


class IncrementalExportTest(unittest.TestCase):
    def fixture(self, jobs=1):
        temporary = tempfile.TemporaryDirectory(prefix="nonproj-make-")
        self.addCleanup(temporary.cleanup)
        return MakeFixture(temporary.name, jobs)

    def test_clean_and_no_op(self):
        for jobs in (1, 4):
            with self.subTest(jobs=jobs):
                fixture = self.fixture(jobs)
                fixture.run()
                self.assertEqual(fixture.events, ["pre", "route_opt", "bitstream"])
                stamp = fixture.out / ".done/bitstream"
                previous = stamp.stat().st_mtime_ns
                fixture.run()
                self.assertEqual(fixture.events, ["pre"])
                self.assertEqual(stamp.stat().st_mtime_ns, previous)

    def test_phase_logs_survive_later_stages_and_export_retries(self):
        fixture = self.fixture()
        fixture.run()
        route_log = fixture.out / "shell.route_opt.log"
        export_log = fixture.out / "shell.bitstream.log"
        self.assertEqual(route_log.read_text(), "phase=route_opt\n")
        self.assertEqual(export_log.read_text(), "phase=bitstream\n")
        before = route_log.stat().st_mtime_ns
        (fixture.out / "shell.bit").unlink()
        fixture.run()
        self.assertEqual(route_log.stat().st_mtime_ns, before)
        self.assertEqual(export_log.read_text(), "phase=bitstream\n")

    def test_missing_artifact_reruns_only_export(self):
        for jobs in (1, 4):
            for suffix in ("bit", "bin", "ltx"):
                with self.subTest(jobs=jobs, suffix=suffix):
                    fixture = self.fixture(jobs)
                    fixture.run()
                    artifact = fixture.out / f"shell.{suffix}"
                    artifact.unlink()
                    fixture.run()
                    self.assertEqual(fixture.events, ["pre", "bitstream"])
                    self.assertTrue(artifact.is_file())

    def test_hook_update_reruns_only_export(self):
        fixture = self.fixture()
        fixture.run()
        stamp = (fixture.out / ".done/bitstream").stat().st_mtime_ns
        os.utime(fixture.hook, ns=(stamp + 1, stamp + 1))
        fixture.run()
        self.assertEqual(fixture.events, ["pre", "bitstream"])

    def test_failed_export_is_retried_even_if_artifacts_exist(self):
        fixture = self.fixture()
        fixture.run()
        (fixture.out / "shell.bit").unlink()
        fixture.run(success=False, FAIL_EXPORT=1)
        self.assertFalse((fixture.out / ".done/bitstream").exists())
        fixture.run()
        self.assertEqual(fixture.events, ["pre", "bitstream"])

    def test_missing_output_fails_stage(self):
        fixture = self.fixture()
        result = fixture.run(success=False, OMIT_ARTIFACT="ltx")
        self.assertIn("Missing programming artifact", result)
        self.assertFalse((fixture.out / ".done/bitstream").exists())
        fixture.run()
        self.assertEqual(fixture.events, ["pre", "bitstream"])

    def test_parallel_goals_export_once(self):
        fixture = self.fixture(jobs=4)
        fixture.run("_np_bitstream", str(fixture.out / "shell.bit"))
        self.assertEqual(fixture.events, ["pre", "route_opt", "bitstream"])


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--mock":
        mock_vivado(sys.argv[2], sys.argv[3:])
    else:
        unittest.main()
