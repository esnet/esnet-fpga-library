# Generate reports from the routed checkpoint without rebuilding the design.
# args: checkpoint output-directory ?native-waiver-file ...? ?-waiver-ref reference file ...?
set_param general.maxThreads 4
set checkpoint [lindex $argv 0]
set output [lindex $argv 1]
file mkdir $output
set status [open $output/report_status.tsv w]
proc run_report {name script} {
    global status
    if {[catch {uplevel 1 $script} message]} {
        puts $status "$name\tERROR\t[string map {\n { } \t { }} $message]"
    } else {
        puts $status "$name\tOK"
    }
    flush $status
}
if {[catch {open_checkpoint $checkpoint} message]} {
    puts $status "checkpoint\tERROR\t[string map {\n { } \t { }} $message]"
    close $status
    exit 1
}
puts $status "checkpoint\tOK"
# Waivers belong to the validation session, not the checkpoint on disk.
source [file join [file dirname [info script]] load_waivers.tcl]
if {[catch {load_validation_waivers {*}[lrange $argv 2 end]} message]} {
    puts $status "waivers\tERROR\t[string map {\n { } \t { }} $message]"
    close $status
    exit 1
}

run_report check_timing {check_timing -verbose -file $output/check_timing.rpt}
run_report timing {report_timing_summary -check_timing_verbose -report_unconstrained -file $output/timing.rpt}
run_report bus_skew {report_bus_skew -file $output/bus_skew.rpt}
run_report routing {report_route_status -file $output/routing.rpt}
run_report cdc {report_cdc -details -all_checks_per_endpoint -file $output/cdc.rpt}
run_report cdc_waived {report_cdc -details -all_checks_per_endpoint -waived -file $output/cdc_waived.rpt}
run_report drc {report_drc -file $output/drc.rpt}
run_report methodology {report_methodology -file $output/methodology.rpt}
run_report waivers {report_waivers -file $output/waivers.rpt}
close $status
