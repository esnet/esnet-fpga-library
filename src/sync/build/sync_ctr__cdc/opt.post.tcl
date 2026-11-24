# Verify two parameterized Gray crossings while retaining an unrelated bus.
foreach {instance width} {binary_sync 6 gray_sync 4} {
    set sources [get_cells -hier -filter "NAME =~ $instance/sync_meta_0/g__input_reg.__sync_ff_in_reg*"]
    set meta [get_cells -hier -filter "NAME =~ $instance/sync_meta_0/__sync_ff_meta_reg*"]
    if {[llength $sources] != $width || [llength $meta] != 3*$width} {
        error "Unexpected registered source or pipeline depth in $instance"
    }
    foreach cell $meta {
        if {![get_property ASYNC_REG $cell]} {error "Lost ASYNC_REG: $cell"}
    }
    set first {}
    for {set bit 0} {$bit < $width} {incr bit} {
        set previous [format {%s/sync_meta_0/g__input_reg.__sync_ff_in_reg[%d]} $instance $bit]
        for {set stage 0} {$stage < 3} {incr stage} {
            set cell [format {%s/sync_meta_0/__sync_ff_meta_reg[%d][%d]} $instance $stage $bit]
            set drivers [get_pins -quiet -leaf -of_objects [get_nets -of_objects [get_pins $cell/D]] -filter {DIRECTION == OUT}]
            if {[llength $drivers] != 1 || [get_property NAME $drivers] ne "$previous/Q"} {
                error "Unexpected logic or connectivity before $cell: $drivers"
            }
            if {$stage == 0} {lappend first $cell}
            set previous $cell
        }
    }
    set first [get_cells $first]
    set paths [get_timing_paths -from $sources -to $first -max_paths $width]
    if {[llength $paths] != $width} {error "Missing constrained Gray paths in $instance"}
    foreach path $paths {
        if {abs([get_property REQUIREMENT $path] - 8.0) > 0.001} {
            error "Gray path lacks its source-period max delay: $path"
        }
    }
}

report_bus_skew -no_detailed_paths -file gray_bus_skew.rpt
set channel [open gray_bus_skew.rpt]
set skew_text [read $channel]
close $channel
set bounds [regexp -all -inline -line {^\s*(?:NA|Slow|Fast)\s+([0-9.]+)\s+\S+\s+\S+\s*$} $skew_text]
if {[llength $bounds] != 8} {error "Expected skew constraints on the three counters and unrelated bus"}
foreach {row bound} $bounds {
    if {abs($bound - 2.9) > 0.001} {error "Unexpected bus-skew bound: $bound"}
}

report_cdc -details -all_checks_per_endpoint -file cdc_before.rpt
set violations [get_cdc_violations -filter {CHECK == CDC-6}]
if {[llength $violations] != 3} {error "Expected three multi-bit crossings before waivers"}
if {[llength [get_cdc_violations -filter {CHECK == CDC-3 && ENDPOINT_PIN =~ single_bit_sync/*}]] != 1} {error "Expected a recognized one-bit crossing"}
if {[llength [get_cdc_violations -quiet -filter {SEVERITY == Critical}]]} {error "Unexpected critical CDC finding"}

# Make exports the source-library root because Vivado copies this hook and
# executes it in a checkpoint-only project without the original source files.
set library_root $::env(SYNC_CTR_CDC_LIB_ROOT)
source [file join $library_root scripts/vivado/validation/load_waivers.tcl]
load_validation_waivers -waiver-ref sync_ctr [file join $library_root src/sync/build/sync_ctr/waivers.xdc]
report_cdc -details -all_checks_per_endpoint -file cdc_after.rpt
set remaining [get_cdc_violations -filter {CHECK == CDC-6 && IS_WAIVED == 0}]
if {[llength $remaining] != 1 || ![string match {unrelated_sync/*} [get_property ENDPOINT_PIN $remaining]]} {
    error "The unrelated multi-bit bus must remain unwaived: $remaining"
}
report_cdc -details -all_checks_per_endpoint -waived -file cdc_waived.rpt
set waived [get_cdc_violations -filter {CHECK == CDC-6 && IS_WAIVED == 1}]
if {[llength $waived] != 2} {error "Expected exactly the two Gray crossings to be waived"}
puts "PASS: two registered Gray crossings constrained and waived; unrelated multi-bit bus remains visible"
