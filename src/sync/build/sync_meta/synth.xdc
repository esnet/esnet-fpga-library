# ===================================================
# CDC timing exceptions for sync_level
# ===================================================
# NOTE: Timing exceptions contained in this XDC file are scoped to sync_level instances.
#       This file should be included using:
#       read_xdc -unmanaged -ref sync_level <path-to-common-lib>/sync/build/sync_level/synth.xdc
set clk_in  [get_clocks -quiet -of [get_ports clk_in]]
set clk_out [get_clocks -quiet -of [get_ports clk_out]]

# Determine clock periods for max_delay/skew constraints
if { $clk_in != "" } {
    set clk_in_period  [get_property -quiet -min PERIOD $clk_in]
} else {
    set clk_in_period 100
}
if { $clk_out != "" } {
    set clk_out_period [get_property -quiet -min PERIOD $clk_out]
} else {
    set clk_out_period 100
}

# Timing exception for path between clk_in and clk_out domains
if { $clk_in != "" } {
    # Preferred method is to constrain max delay of path between clock domains
    set_max_delay -quiet -from [get_cells __sync_ff_in_reg*] -to [get_cells __sync_ff_meta_reg[0]*] $clk_in_period -datapath_only
} else {
    # Set false path between input and output flops when clock details are unavailable
    set_false_path -quiet -to [get_cells __sync_ff_meta_reg[0]*]
    puts "SYNC_LEVEL (WARNING): Couldn't determine input clock period, using false_path instead of max_delay."
}

# For multi-bit bus, also constrain skew
if { [llength [get_cells __sync_ff_in_reg*]] > 1 } {
    set_bus_skew -quiet -from [get_cells __sync_ff_in_reg*] -to [get_cells __sync_ff_meta_reg[0]*] [expr min ($clk_in_period, $clk_out_period)]
}



