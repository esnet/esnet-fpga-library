# The normal OOC flow has synthesized and optimized two live consumers.
# Remove one consumer here to model its disappearance after linking an OOC
# core, then sweep again and check the resulting CDC structure.
set stages 3
set width 6
foreach instance {live_sync unused_sync} {
    set meta [get_cells -quiet -hier -filter "NAME =~ $instance/*__sync_ff_meta_reg*"]
    if {[llength $meta] != $stages * $width} {
        error "Expected a complete synchronizer before removing the consumer: $instance"
    }
}
foreach port [get_ports unused_out*] {
    disconnect_net -net [get_nets -of_objects $port] -objects $port
    remove_port $port
}
opt_design -sweep

set unused [get_cells -quiet -hier -filter {NAME =~ unused_sync/*__sync_ff*}]
if {[llength $unused]} {error "Unused CDC registers survived optimization: $unused"}
set source [get_cells -quiet -hier -filter {NAME =~ live_sync/*__sync_ff_in_reg*}]
set meta [get_cells -quiet -hier -filter {NAME =~ live_sync/*__sync_ff_meta_reg*}]
if {[llength $source] != $width || [llength $meta] != $stages * $width} {
    error "Optimization changed the live input register or synchronizer depth"
}
foreach cell $meta {
    if {![get_property ASYNC_REG $cell]} {error "Lost ASYNC_REG on $cell"}
}
for {set bit 0} {$bit < $width} {incr bit} {
    set previous [format {live_sync/sync_meta_0/g__input_reg.__sync_ff_in_reg[%d]} $bit]
    for {set stage 0} {$stage < $stages} {incr stage} {
        set cell [format {live_sync/sync_meta_0/__sync_ff_meta_reg[%d][%d]} $stage $bit]
        set drivers [get_pins -quiet -leaf -of_objects [get_nets -of_objects [get_pins $cell/D]] -filter {DIRECTION == OUT}]
        if {[llength $drivers] != 1 || [get_property NAME $drivers] ne "$previous/Q"} {
            error "Live synchronizer has unexpected logic or connectivity before $cell: $drivers"
        }
        set previous $cell
    }
}
report_cdc -details -all_checks_per_endpoint -file cdc.rpt
set report [open cdc.rpt]
set text [read $report]
close $report
if {![regexp -line {^CDC-6\s+Warning\s+1\s} $text] ||
    [regexp -line {^CDC-\d+\s+Critical\s} $text] ||
    ![regexp {Multi-bit synchronized with ASYNC_REG property\s+3\s} $text]} {
    error "Expected one recognized depth-three live crossing and no critical CDC findings"
}
puts "PASS: unused CDC chain removed; live registered Gray boundary and three ASYNC_REG stages preserved"
