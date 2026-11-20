"""Check board context before source loading, linking, and checkpoint operations."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

from test_build_non_proj_bitstream import MakeFixture

RUNNER = Path(__file__).resolve().parents[1] / "vivado/build_non_proj.tcl"


class BoardContextTest(unittest.TestCase):
    def run_phase(self, phase, board="vendor:board:part0:1.0", repo=True,
                  board_device="device", missing_repo=False):
        temporary = tempfile.TemporaryDirectory(prefix="nonproj-board-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        repository = root / "board repository"
        if not missing_repo:
            repository.mkdir()
        source = root / "sources.tcl"
        source.write_text("checked sources\n")
        constraint = root / "timing.xdc"
        constraint.write_text("timing")
        args = [phase, "top", "-part", "device", "-out_dir", str(root),
                "-sources_tcl", str(source), "-constraints_xdc_synth", str(constraint),
                "-constraints_xdc", str(constraint), "-top_dcp", "top.dcp",
                "-cell_dcp", "core", "core.dcp"]
        if board is not None:
            args += ["-board_part", board]
        if repo:
            args += ["-board_repo", str(repository)]
        driver = root / "driver.tcl"
        driver.write_text(r'''
set argv {@ARGS@}
set argc [llength $argv]
set requested_board {@BOARD@}
set board_device {@DEVICE@}
set expected_repo {@REPO@}
set repositories installed-repo
set active_board {}
set active_part device
proc get_param {name} {return $::repositories}
proc set_param {name value} {
    if {$name ne "board.repoPaths"} {error "Unexpected parameter"}
    if {[lindex $value end] ne "installed-repo"} {error "Existing board repository was discarded"}
    set ::repositories $value
    puts REPOSITORY_SET
}
proc create_project {args} {
    if {$::expected_repo ne "" && [lindex $::repositories 0] ne $::expected_repo} {
        error "Board repository was not configured before project creation"
    }
    puts PROJECT_CREATED
}
proc open_checkpoint {path} {
    create_project
    set ::active_board restored-board
    puts CHECKPOINT_OPENED
}
proc current_project {} {return project}
proc get_board_parts {args} {
    if {[lindex $args end] eq "unknown"} {return {}}
    return board
}
proc set_property {name value object} {
    if {$name ne "board_part" || $object ne "project"} {error "Unexpected property"}
    set ::active_board $value
    set ::active_part $::board_device
    puts BOARD_SET
}
proc get_property {name object} {
    if {$name ne "PART_NAME" || $object ne "board"} {error "Unexpected property query"}
    return $::board_device
}
proc checked {args} {
    if {$::requested_board ne "" && $::active_board ne $::requested_board} {
        error "Board context missing before $args"
    }
    puts "OPERATION [lindex $args 0]"
}
proc get_files {args} {return {}}
proc get_filesets {args} {return sources_1}
proc get_bd_designs {args} {return {}}
foreach command {read_xdc synth_design read_checkpoint link_design write_checkpoint
                 opt_design place_design phys_opt_design route_design
                 write_bitstream write_device_image write_debug_probes write_hw_platform} {
    interp alias {} $command {} checked $command
}
source {@RUNNER@}
'''.replace("@ARGS@", " ".join("{" + arg + "}" for arg in args))
             .replace("@BOARD@", board or "").replace("@DEVICE@", board_device)
             .replace("@REPO@", str(repository) if repo else "")
             .replace("@RUNNER@", str(RUNNER)))
        return subprocess.run(["tclsh", str(driver)], text=True, capture_output=True)

    def test_board_context_is_present_in_every_phase(self):
        for phase in ("synth", "link", "opt", "place", "place_opt", "route",
                      "route_opt", "bitstream", "device_image", "xsa"):
            with self.subTest(phase=phase):
                result = self.run_phase(phase)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertLess(result.stdout.index("BOARD_SET"), result.stdout.index("OPERATION"))

    def test_missing_repository_fails_before_creating_project(self):
        result = self.run_phase("synth", missing_repo=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Board repository does not exist", result.stderr)
        self.assertNotIn("PROJECT_CREATED", result.stdout)

    def test_board_device_mismatch_fails_before_loading_sources(self):
        result = self.run_phase("synth", board_device="different-device")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("but 'device' was requested", result.stderr)
        self.assertNotIn("OPERATION", result.stdout)

    def test_unknown_board_fails_before_loading_sources(self):
        result = self.run_phase("synth", board="unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Board part is unavailable", result.stderr)
        self.assertNotIn("BOARD_SET", result.stdout)
        self.assertNotIn("OPERATION", result.stdout)

    def test_optional_board_and_repository_are_supported(self):
        for board, repo in ((None, False), ("", True), ("vendor:board:part0:1.0", False)):
            with self.subTest(board=board, repo=repo):
                result = self.run_phase("synth", board=board, repo=repo)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual("BOARD_SET" in result.stdout, bool(board))

    def test_empty_board_keeps_checkpoint_board_context(self):
        result = self.run_phase("route", board="", repo=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("BOARD_SET", result.stdout)


class BoardMakeTest(unittest.TestCase):
    def arguments(self, **variables):
        temporary = tempfile.TemporaryDirectory(prefix="nonproj-board-make-")
        self.addCleanup(temporary.cleanup)
        fixture = MakeFixture(temporary.name)
        env = os.environ.copy()
        for key in ("MAKEFLAGS", "MFLAGS", "MAKELEVEL", "BOARD_PART", "BOARD_REPO"):
            env.pop(key, None)
        result = subprocess.run(
            ["make", "-ns", "_np_route_opt", *(f"{k}={v}" for k, v in variables.items())],
            cwd=fixture.root, env=env, text=True, capture_output=True, check=True,
        )
        command = next(line for line in result.stdout.splitlines() if "-tclargs route_opt" in line)
        return shlex.split(command)

    def test_make_forwards_board_context(self):
        args = self.arguments(BOARD_PART="vendor:board:part0:1.0", BOARD_REPO="/tmp/boards")
        self.assertEqual(args[args.index("-board_part") + 1], "vendor:board:part0:1.0")
        self.assertEqual(args[args.index("-board_repo") + 1], "/tmp/boards")

    def test_make_omits_unset_board_options(self):
        args = self.arguments()
        self.assertNotIn("-board_part", args)
        self.assertNotIn("-board_repo", args)

    def test_make_preserves_quoted_empty_board_part(self):
        args = self.arguments(BOARD_PART='""')
        self.assertEqual(args[args.index("-board_part") + 1], "")
