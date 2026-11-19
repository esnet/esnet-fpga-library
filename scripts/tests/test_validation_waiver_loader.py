"""Exercise reference scoping and loader failures with Tcl command stubs."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

LOADER = Path(__file__).resolve().parents[1] / "vivado/validation/load_waivers.tcl"


@unittest.skipUnless(shutil.which("tclsh"), "requires tclsh")
class WaiverLoaderTests(unittest.TestCase):
    def run_loader(self, body):
        with tempfile.TemporaryDirectory() as temp:
            script = Path(temp) / "test.tcl"
            script.write_text('''
set calls {}
proc get_cells {args} {
    if {[lindex $args end] ne [list REF_NAME == [lindex [lindex $args end] end] || ORIG_REF_NAME == [lindex [lindex $args end] end]]} {
        error "Reference filter was not a literal equality"
    }
    if {[lindex [lindex $args end] end] eq "missing"} { return {} }
    return {top/first top/second}
}
proc read_xdc {args} {
    if {[lindex $args end] eq "broken.xdc"} {error "Bad waiver XDC"}
    lappend ::calls $args
}
source [lindex $argv 0]
''' + body)
            result = subprocess.run(["tclsh", str(script), str(LOADER)], text=True, capture_output=True)
            status = Path(temp) / "report_status.tsv"
            result.report_status = status.read_text() if status.exists() else ""
            return result

    def test_multiple_references_and_global_files_keep_their_scope(self):
        result = self.run_loader('''
load_validation_waivers global.xdc -waiver-ref ram {ram waivers.xdc} -waiver-ref fifo fifo.xdc
set expected [list [list global.xdc] [list -ref ram {ram waivers.xdc}] [list -ref fifo fifo.xdc]]
if {$calls ne $expected} {error "Unexpected XDC calls: $calls"}
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("reference=ram, instances=2", result.stdout)
        self.assertIn("reference=fifo, instances=2", result.stdout)

    def test_missing_reference_fails_without_loading_unscoped_waivers(self):
        result = self.run_loader('''
if {![catch {load_validation_waivers -waiver-ref missing file.xdc} message]} {error "Accepted missing reference"}
if {![string match {*No instances*} $message] || [llength $calls]} {error "Unexpected result: $message $calls"}
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_malformed_reference_arguments_fail(self):
        for args in ("-waiver-ref", "-waiver-ref ram"):
            with self.subTest(args=args):
                result = self.run_loader(f"load_validation_waivers {args}\n")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Expected reference and XDC path", result.stderr)

    def test_reference_error_aborts_report_collection_with_failure_status(self):
        result = self.run_loader('''
proc set_param {args} {}
proc open_checkpoint {args} {}
set report [file join [file dirname [lindex $argv 0]] report_build.tcl]
set argv [list fake_checkpoint [file dirname [info script]] -waiver-ref missing file.xdc]
source $report
''')
        self.assertEqual(result.returncode, 1)
        self.assertIn("checkpoint\tOK", result.report_status)
        self.assertIn("waivers\tERROR\tNo instances", result.report_status)
        self.assertNotIn("cdc\tOK", result.report_status)

    def test_xdc_errors_propagate(self):
        for args in ("broken.xdc", "-waiver-ref ram broken.xdc"):
            with self.subTest(args=args):
                result = self.run_loader(f"load_validation_waivers {args}\n")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Bad waiver XDC", result.stderr)


if __name__ == "__main__":
    unittest.main()
