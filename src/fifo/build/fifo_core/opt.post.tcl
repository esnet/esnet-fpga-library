# Keep the CDC report and timing assertions independent: a waiver must not
# replace pointer constraints or suppress ordinary read-domain timing.
proc fifo_cdc_signature {violation} {
    return [list [get_property CHECK $violation] [get_property STARTPOINT_PIN $violation] \
        [get_property ENDPOINT_PIN $violation] [get_property EXCEPTION $violation]]
}

proc fifo_cdc_check_timing {} {
    set snapshot {}
    foreach {instance width clock} {lut_std 13 rd_clk lut_fwft 17 rd_clk lut_scalar 1 rd_clk synchronous_fifo 7 wr_clk} {
        set registers [get_cells -hier -filter "NAME =~ $instance/fifo/i_mem_ram_sdp/i_xilinx_ram_sdp/g__lutram.i_xilinx_ram_sdp_lutram/rd_data_reg*"]
        if {[llength $registers] != $width} {error "Unexpected read-data register count in $instance"}
        set paths [get_timing_paths -to $registers -max_paths $width]
        if {[llength $paths] != $width} {error "Missing read-address timing in $instance"}
        foreach path $paths {
            if {[get_property STARTPOINT_CLOCK $path] ne $clock || [get_property ENDPOINT_CLOCK $path] ne $clock} {
                error "Read-address timing must remain local to $clock: $path"
            }
            lappend snapshot [list [get_property ENDPOINT_PIN $path] [get_property REQUIREMENT $path]]
        }
    }
    foreach instance {bram_std bram_fwft} {
        if {![llength [get_cells -hier -filter "NAME =~ $instance/fifo/i_mem_ram_sdp/* && REF_NAME =~ RAMB*"]]} {
            error "Expected block RAM implementation in $instance"
        }
    }

    set sources [get_cells -hier -filter {NAME =~ */sync_meta_0/g__input_reg.__sync_ff_in_reg*}]
    set meta [get_cells -hier -filter {NAME =~ */sync_meta_0/__sync_ff_meta_reg*}]
    if {[llength $sources] != 78 || [llength $meta] != 234} {error "Missing Gray-pointer source or synchronizer stages"}
    set first {}
    foreach cell $meta {
        if {![get_property ASYNC_REG $cell]} {error "Missing ASYNC_REG: $cell"}
        if {[regexp {/sync_meta_0/__sync_ff_meta_reg\[0\]\[[0-9]+\]$} $cell]} {lappend first $cell}
    }
    set first [get_cells $first]
    set paths [get_timing_paths -from $sources -to $first -max_paths 78]
    if {[llength $paths] != 78} {error "Missing pointer timing paths"}
    foreach path $paths {
        set period [get_property PERIOD [get_clocks [get_property STARTPOINT_CLOCK $path]]]
        if {abs([get_property REQUIREMENT $path] - $period) > 0.001 || [get_property LOGIC_LEVELS $path] != 0} {
            error "Pointer path lost its direct registered source or source-period bound: $path"
        }
        lappend snapshot [list [get_property ENDPOINT_PIN $path] [get_property REQUIREMENT $path]]
    }
    report_bus_skew -no_detailed_paths -file fifo_bus_skew.rpt
    set channel [open fifo_bus_skew.rpt]
    set skew_text [read $channel]
    close $channel
    set bounds [regexp -all -inline -line {^\s*(?:NA|Slow|Fast)\s+([0-9.]+)\s+\S+\s+\S+\s*$} $skew_text]
    if {[llength $bounds] != 20} {error "Expected ten FIFO pointer bus-skew constraints"}
    foreach {row bound} $bounds {
        if {abs($bound - 2.9) > 0.001} {error "Unexpected pointer bus-skew bound: $bound"}
    }
    return [lsort $snapshot]
}

set timing_before [fifo_cdc_check_timing]
report_cdc -details -all_checks_per_endpoint -file cdc_before.rpt
set payloads [get_cdc_violations -filter {CHECK == CDC-15}]
if {[llength $payloads] != 42} {error "Expected 31 FIFO and 11 unrelated RAM payload crossings"}
foreach {instance width} {lut_std 13 lut_fwft 17 lut_scalar 1 unrelated_ram 11} {
    if {[llength [get_cdc_violations -filter "CHECK == CDC-15 && ENDPOINT_PIN =~ $instance/*"]] != $width} {
        error "Unexpected payload CDC coverage in $instance"
    }
}
set preserved {}
foreach violation [get_cdc_violations] {
    set endpoint [get_property ENDPOINT_PIN $violation]
    if {[get_property CHECK $violation] ne "CDC-15" || [string match {unrelated_ram/*} $endpoint]} {
        lappend preserved [fifo_cdc_signature $violation]
    }
}

# Make exports the root because Vivado copies this hook into the project.
set library_root $::env(FIFO_CORE_CDC_LIB_ROOT)
source [file join $library_root scripts/vivado/validation/load_waivers.tcl]
load_validation_waivers -waiver-ref fifo_core [file join $library_root src/fifo/build/fifo_core/waivers.xdc]
if {[llength [get_waivers -filter {ID == CDC-15}]] != 4} {
    error "Expected waivers only for the four LUTRAM FIFO instances"
}
report_cdc -details -all_checks_per_endpoint -file cdc_after.rpt
set remaining {}
foreach violation [get_cdc_violations -filter {IS_WAIVED == 0}] {
    lappend remaining [fifo_cdc_signature $violation]
}
if {[lsort $remaining] ne [lsort $preserved]} {error "Waiver changed unrelated RAM or FIFO control findings"}
if {[llength [get_cdc_violations -filter {CHECK == CDC-15 && IS_WAIVED == 0}]] != 11} {
    error "The generic RAM payload crossings must remain unwaived"
}
report_cdc -details -all_checks_per_endpoint -waived -file cdc_waived.rpt
set waived [get_cdc_violations -filter {CHECK == CDC-15 && IS_WAIVED == 1}]
if {[llength $waived] != 31} {error "Expected exactly 31 FIFO payload crossings to be waived"}
if {[fifo_cdc_check_timing] ne $timing_before} {error "Waiver changed timing coverage"}
puts "PASS: 31 FIFO payload crossings waived; 11 generic RAM crossings and all pointer/address constraints retained"
