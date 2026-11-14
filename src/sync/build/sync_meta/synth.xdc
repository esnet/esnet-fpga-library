# ===================================================
# CDC timing exceptions for sync_meta
# ===================================================
# NOTE: Timing exceptions contained in this XDC file are scoped to sync_meta instances.
#       This file should be included using:
#       read_xdc -ref sync_meta <path-to-common-lib>/sync/build/sync_meta/synth.xdc
set clk_in  [get_clocks -quiet -of [get_ports clk_in]]
set clk_out [get_clocks -quiet -of [get_ports clk_out]]

# Determine clock periods for max_delay/skew constraints (default 100 ns when clock is unavailable)
set clk_in_period  [expr {$clk_in  ne "" ? [get_property -quiet -min PERIOD $clk_in]  : 100}]
set clk_out_period [expr {$clk_out ne "" ? [get_property -quiet -min PERIOD $clk_out] : 100}]

set input_regs [get_cells -quiet -hierarchical -regexp {.*__sync_ff_in_reg.*}]
set meta_regs  [get_cells -quiet -hierarchical -regexp {.*__sync_ff_meta_reg\[0\].*}]
# Constrain max delay of path between clock domains (registered-input mode).
set_max_delay -quiet -from $input_regs -to $meta_regs $clk_in_period -datapath_only

# Constrain skew (harmless on single-bit paths).
set_bus_skew -quiet -from $input_regs -to $meta_regs [expr {min($clk_in_period, $clk_out_period)}]

# With the input register bypassed, except only paths from sig_in into the first
# metastability stage. In registered-input mode no such combinational path exists.
set_false_path -quiet -through [get_ports sig_in] -to [get_pins -quiet -of_objects $meta_regs -filter {REF_PIN_NAME == D}]



