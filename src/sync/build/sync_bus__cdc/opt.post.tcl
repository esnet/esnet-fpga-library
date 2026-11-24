# Prove the payload waiver cannot replace handshake structure or timing bounds.
proc bus_cdc_signature {violation} {
    return [list [get_property CHECK $violation] [get_property STARTPOINT_PIN $violation] \
        [get_property ENDPOINT_PIN $violation] [get_property EXCEPTION $violation]]
}

proc bus_cdc_check_timing {phase} {
    set snapshot {}
    foreach {instance width destination_period} {four_phase 13 2.9 two_phase 17 8 scalar_four 1 2.9 scalar_two 1 8} {
        set sources [get_cells -hier -filter "NAME =~ $instance/__sync_ff_bus_data_in_reg*"]
        set targets [get_cells -hier -filter "NAME =~ $instance/__sync_ff_bus_data_out_reg*"]
        if {[llength $sources] != $width || [llength $targets] != $width} {
            error "Missing payload storage in $instance"
        }
        foreach cell $targets {
            set drivers [get_pins -leaf -of_objects [get_nets -of_objects [get_pins $cell/D]] -filter {DIRECTION == OUT}]
            set source [string map {__sync_ff_bus_data_out_reg __sync_ff_bus_data_in_reg} $cell]
            if {[llength $drivers] != 1 || [get_property NAME $drivers] ne "$source/Q"} {
                error "Payload has intervening logic or incorrect bit connectivity: $cell"
            }
        }
        set paths [get_timing_paths -from $sources -to $targets -max_paths $width]
        if {[llength $paths] != $width} {error "Missing payload timing paths in $instance"}
        foreach path $paths {
            if {abs([get_property REQUIREMENT $path]-3*$destination_period)>0.001 || [get_property LOGIC_LEVELS $path]!=0} {
                error "Payload lacks its three-destination-cycle bound: $path"
            }
            lappend snapshot [list [get_property ENDPOINT_PIN $path] [get_property REQUIREMENT $path]]
        }
        foreach direction {req ack} {
            set prefix $instance/i_sync_event__handshake/i_sync_meta__$direction
            set source [get_cells -hier -filter "NAME =~ $prefix/g__input_reg.__sync_ff_in_reg*"]
            set stages [lsort -dictionary [get_cells -hier -filter "NAME =~ $prefix/__sync_ff_meta_reg*"]]
            if {[llength $source] != 1 || [llength $stages] != 3} {
                error "Missing registered, three-stage $direction crossing in $instance"
            }
            set previous $source
            foreach cell $stages {
                if {![get_property ASYNC_REG $cell]} {error "Lost ASYNC_REG: $cell"}
                set drivers [get_pins -leaf -of_objects [get_nets -of_objects [get_pins $cell/D]] -filter {DIRECTION == OUT}]
                if {[llength $drivers]!=1 || [get_property NAME $drivers] ne "$previous/Q"} {
                    error "Logic or incorrect connectivity in $instance/$direction: $cell"
                }
                set previous $cell
            }
            set paths [get_timing_paths -from $source -to [get_cells [lindex $stages 0]] -max_paths 1]
            if {[llength $paths]!=1} {error "Missing $direction timing bound in $instance"}
            set path [lindex $paths 0]
            set period [get_property PERIOD [get_clocks [get_property STARTPOINT_CLOCK $path]]]
            if {abs([get_property REQUIREMENT $path]-$period)>0.001} {error "Incorrect $direction delay bound"}
            lappend snapshot [list [get_property ENDPOINT_PIN $path] [get_property REQUIREMENT $path]]
        }
    }
    report_bus_skew -no_detailed_paths -file bus_skew_$phase.rpt
    set channel [open bus_skew_$phase.rpt]
    set skew_text [read $channel]
    close $channel
    set bounds [regexp -all -inline -line {^\s*(?:NA|Slow|Fast)\s+([0-9.]+)\s+\S+\s+\S+\s*$} $skew_text]
    if {[llength $bounds]!=24} {error "Expected four payload and eight handshake skew bounds"}
    set counts [dict create short 0 forward 0 reverse 0]
    foreach {row bound} $bounds {
        if {abs($bound-2.9)<0.001} {dict incr counts short} \
        elseif {abs($bound-8.7)<0.001} {dict incr counts forward} \
        elseif {abs($bound-24)<0.001} {dict incr counts reverse} \
        else {error "Unexpected bus-skew bound: $bound"}
    }
    if {$counts ne {short 8 forward 2 reverse 2}} {error "Missing payload or handshake skew bounds: $counts"}
    return [lsort $snapshot]
}

set timing_before [bus_cdc_check_timing before]
report_cdc -details -all_checks_per_endpoint -file cdc_before.rpt
if {[llength [get_cdc_violations -filter {CHECK == CDC-15}]]!=39} {
    error "Expected 32 handshake and seven unrelated payload findings"
}
if {[llength [get_cdc_violations -quiet -filter {SEVERITY == Critical}]]} {error "Unexpected critical CDC finding"}
set preserved {}
foreach violation [get_cdc_violations] {
    if {[get_property CHECK $violation] ne "CDC-15" || [string match {unrelated/*} [get_property ENDPOINT_PIN $violation]]} {
        lappend preserved [bus_cdc_signature $violation]
    }
}

# Make exports the source-library root because Vivado copies this hook.
set library_root $::env(SYNC_BUS_CDC_LIB_ROOT)
source [file join $library_root scripts/vivado/validation/load_waivers.tcl]
load_validation_waivers -waiver-ref sync_bus [file join $library_root src/sync/build/sync_bus/waivers.xdc]
report_cdc -details -all_checks_per_endpoint -file cdc_after.rpt
set remaining {}
foreach violation [get_cdc_violations -filter {IS_WAIVED == 0}] {lappend remaining [bus_cdc_signature $violation]}
if {[lsort $preserved] ne [lsort $remaining]} {error "Waiver changed unrelated payload or handshake findings"}
report_cdc -details -all_checks_per_endpoint -waived -file cdc_waived.rpt
if {[llength [get_cdc_violations -filter {CHECK == CDC-15 && IS_WAIVED == 1}]]!=32} {
    error "Expected exactly 32 waived handshake payload findings"
}
if {[bus_cdc_check_timing after] ne $timing_before} {error "Waiver changed timing coverage"}
puts "PASS: 32 handshake payload crossings waived; seven unrelated crossings, direct req/ack synchronizers and timing bounds retained"
