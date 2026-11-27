"""Check flash export arguments and recovery without synthesis or implementation."""

from pathlib import Path
import subprocess
import tempfile
import unittest

from test_build_non_proj_bitstream import MakeFixture, RUNNER


class FlashExportTest(unittest.TestCase):
    def test_flash_export_uses_only_existing_bitstream(self):
        with tempfile.TemporaryDirectory(prefix="flash export ") as tmp:
            root = Path(tmp)
            bitfile = root / "shell.bit"
            bitfile.write_text("bitstream")
            driver = root / "driver.tcl"
            driver.write_text('''
set argv [list flash shell -out_dir {@ROOT@} -cfgmem_size 128 \\
    -cfgmem_interface SPIx4 -cfgmem_load_address 0x01002000]
set argc [llength $argv]
proc write_cfgmem {args} {
    set expected [list -force -format mcs -size 128 -interface SPIx4 \\
        -loadbit [list up 0x01002000 {@ROOT@/shell.bit}] -file {@ROOT@/shell.mcs}]
    if {$args ne $expected} {error "Unexpected flash export arguments: $args"}
    close [open {@ROOT@/shell.mcs} w]
}
source {@RUNNER@}
'''.replace("@ROOT@", str(root)).replace("@RUNNER@", str(RUNNER)))
            result = subprocess.run(["tclsh", str(driver)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((root / "shell.mcs").is_file())
            bitfile.unlink()
            result = subprocess.run(["tclsh", str(driver)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing flash input bitstream", result.stderr)
            bitfile.write_text("bitstream")
            driver.write_text(driver.read_text().replace("-cfgmem_size 128", ""))
            result = subprocess.run(["tclsh", str(driver)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Flash export requires CFGMEM_SIZE", result.stderr)

    def test_flash_stage_recovers_missing_output_without_rewriting_bitstream(self):
        for jobs in (1, 4):
            with self.subTest(jobs=jobs), tempfile.TemporaryDirectory() as tmp:
                fixture = MakeFixture(tmp, jobs=jobs)
                path = Path(tmp) / "Makefile"
                path.write_text(path.read_text().replace("BUILD_STAGES := route_opt bitstream",
                    "BUILD_STAGES := route_opt bitstream flash\n"
                    "CFGMEM_SIZE := 128\nCFGMEM_INTERFACE := SPIx4\n"
                    "CFGMEM_LOAD_ADDRESS := 0x01002000"))
                fixture.run("_np_flash")
                self.assertEqual(fixture.events, ["pre", "route_opt", "bitstream", "flash"])
                bit = fixture.out / "shell.bit"
                bit_mtime = bit.stat().st_mtime_ns
                fixture.run("_np_flash")
                self.assertEqual(fixture.events, ["pre"])
                mcs = fixture.out / "shell.mcs"
                mcs.unlink()
                fixture.run("_np_flash", str(mcs))
                self.assertEqual(fixture.events, ["pre", "flash"])
                self.assertEqual(bit.stat().st_mtime_ns, bit_mtime)
                mcs.unlink()
                fixture.run("_np_flash", success=False, OMIT_ARTIFACT="mcs")
                self.assertFalse((fixture.out / ".done/flash").exists())
                fixture.run("_np_flash")
                self.assertEqual(fixture.events, ["pre", "flash"])
                bit.unlink()
                fixture.run("_np_flash")
                self.assertEqual(fixture.events, ["pre", "bitstream", "flash"])


if __name__ == "__main__":
    unittest.main()
