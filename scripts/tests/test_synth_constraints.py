"""Exercise scoped constraint selection and registration without a Vivado license."""
from pathlib import Path
import subprocess
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'vivado/synth_constraints.tcl'


class SynthConstraintsTest(unittest.TestCase):
    def run_tcl(self, body):
        driver = r'''
set designs {}
set refs {}
set top wrapper
set files {}
set events {}
set CONSTR_MGMT_TYPE {-unmanaged}
proc current_design {args} {return $::designs}
proc get_property {property object} {
    if {$property ne "TOP"} {error "Unexpected property $property"}
    return $::top
}
proc get_cells {args} {
    foreach ref $::refs {
        if {[string first "REF_NAME == $ref " [lindex $args end]]>=0} {return cell}
    }
    return {}
}
proc get_files {args} {
    set path [lindex $args end]
    if {$path in $::files} {return $path}
    return {}
}
proc read_xdc {args} {
    if {[lindex $args 0] eq "-quiet"} {error "Errors must not be suppressed"}
    set file [lindex $args end]
    if {$file eq "bad.xdc"} {error "Invalid constraint"}
    lappend ::events [list read {*}$args]
    lappend ::files $file
}
proc set_property {args} {lappend ::events [list property {*}$args]}
proc remove_files {file} {
    lappend ::events [list remove $file]
    set ::files [lsearch -all -inline -not -exact $::files $file]
}
source {@HELPER@}
'''.replace('@HELPER@', str(HELPER))
        result = subprocess.run(['tclsh'], input=driver + '\n' + body,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '', result.stderr)
        return result.stdout.strip()

    def test_entry_point_registers_late_unmanaged_tcl(self):
        self.assertEqual(self.run_tcl('''
::synthConstraints::load generated.tcl {sync_meta meta.xdc}
puts $events
'''), '{read -unmanaged generated.tcl} {property FILE_TYPE TCL generated.tcl} {property PROCESSING_ORDER LATE generated.tcl}')

    def test_managed_entry_point(self):
        self.assertEqual(self.run_tcl('''
set CONSTR_MGMT_TYPE {}
::synthConstraints::load generated.tcl {}
puts $events
'''), '{read generated.tcl} {property FILE_TYPE TCL generated.tcl} {property PROCESSING_ORDER LATE generated.tcl}')

    def test_only_active_reference_is_registered_once(self):
        self.assertEqual(self.run_tcl('''
set designs design
set refs sync_meta
::synthConstraints::load generated.tcl {sync_meta meta.xdc sync_bus bus.xdc}
::synthConstraints::load generated.tcl {sync_meta meta.xdc sync_bus bus.xdc}
puts $events
'''), '{read -ref sync_meta meta.xdc} {property PROCESSING_ORDER LATE meta.xdc} {property PROCESSING_ORDER LATE meta.xdc}')

    def test_top_reference_is_supported(self):
        self.assertEqual(self.run_tcl('''
set designs design
set top sync_meta
::synthConstraints::load generated.tcl {sync_meta meta.xdc}
puts $events
'''), '{read -ref sync_meta meta.xdc} {property PROCESSING_ORDER LATE meta.xdc}')

    def test_reference_removed_by_optimization_is_unregistered(self):
        self.assertEqual(self.run_tcl('''
set designs design
set files meta.xdc
::synthConstraints::load generated.tcl {sync_meta meta.xdc}
puts $events
'''), '{remove meta.xdc}')

    def test_constraint_errors_propagate(self):
        self.assertEqual(self.run_tcl('''
set designs design
set refs sync_meta
puts [catch {::synthConstraints::load generated.tcl {sync_meta bad.xdc}} message]
puts $message
'''), '1\nInvalid constraint')
