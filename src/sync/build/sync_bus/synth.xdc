# ===================================================
# CDC timing exceptions for sync_bus
# ===================================================
# NOTE: Timing exceptions contained in this XDC file are scoped to sync_bus instances.
#       This file should be included using:
#       read_xdc -unmanaged -ref sync_bus <path-to-common-lib>/sync/build/sync_bus/synth.xdc
set clk_out [get_clocks -quiet -of [get_ports clk_out]]

# Determine output clock period for max_delay/skew constraints
if { $clk_out != "" } {
    set clk_out_period [get_property -quiet -min PERIOD $clk_out]
} else {
    set clk_out_period 100
}

# Determine number of retiming flops in request (input-to-output) handshake direction
set req_retiming_stages [llength [get_cells i_sync_event__handshake/i_sync_meta__req/__sync_ff_meta_reg[*]]]

# Constrain max delay of bus signals between clock domains
set_max_delay -quiet -from [get_cells __sync_ff_bus_data_in_reg*] -to [get_cells __sync_ff_bus_data_out_reg*] [expr {$clk_out_period * $req_retiming_stages}] -datapath_only

# For multi-bit bus, also constrain skew
if { [llength [get_cells __sync_ff_bus_data_in_reg*]] > 1 } {
    set_bus_skew -quiet -from [get_cells __sync_ff_bus_data_in_reg*] -to [get_cells __sync_ff_bus_data_out_reg*] [expr {$clk_out_period * $req_retiming_stages}]
}



