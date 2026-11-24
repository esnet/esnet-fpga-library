create_clock -name clk_a -period 8 [get_ports clk_a]
create_clock -name clk_b -period 2.9 [get_ports clk_b]

# Keep the deliberately unsafe negative-control bus timed without imposing
# a relationship between the two clocks or masking the real handshake bounds.
set_max_delay -datapath_only 8 \
    -from [get_cells -hier -filter {NAME =~ unrelated/__sync_ff_bus_data_in_reg*}] \
    -to [get_cells -hier -filter {NAME =~ unrelated/__sync_ff_bus_data_out_reg*}]
