# Check source selection in the synthesis log: checkpoint reload restores
# timing constraints from a binary archive without the original file objects.
if {[info exists ::env(SYNTH_CONSTRAINTS_SYNTH_LOG)]} {
    set stream [open $::env(SYNTH_CONSTRAINTS_SYNTH_LOG)]
    set log [read $stream]
    close $stream
    if {[regexp {CRITICAL WARNING:|ERROR:} $log]} {
        error "Unexpected synthesis constraint warning or error"
    }
    if {[string first /sync_meta/synth.xdc $log]<0} {
        error "Active synchronizer constraints were not read"
    }
    foreach ref {sync_areset sync_bus xilinx_ram_sdp_lutram bus_pipe_slr} {
        if {[string first /$ref/synth.xdc $log]>=0} {
            error "Read constraints for absent reference $ref"
        }
    }
}
set source [get_cells -hier -filter {NAME =~ i_sync_meta/*__sync_ff_in_reg*}]
set stages [get_cells -hier -regexp {i_sync_meta/__sync_ff_meta_reg\[0\].*}]
set paths [get_timing_paths -from $source -to $stages -max_paths 8]
if {[llength $paths]!=8} {error "Missing synchronizer paths after checkpoint reload"}
foreach path $paths {
    if {abs([get_property REQUIREMENT $path]-8)>0.001} {
        error "Lost source-clock max-delay bound after checkpoint reload"
    }
}
report_bus_skew -no_detailed_paths -file constraint_selection_bus_skew.rpt
set stream [open constraint_selection_bus_skew.rpt]
set text [read $stream]
close $stream
if {![regexp -line {^\s*(?:NA|Slow|Fast)\s+2\.900\s+} $text]} {
    error "Lost destination-clock bus-skew bound"
}
puts "PASS: unused reference XDCs skipped; 8 ns delay and 2.9 ns skew bounds retained after checkpoint reload"
