# ===================================================
# CDC timing exceptions for xilinx_ram_sdp_lutram
# ===================================================
# NOTE: Timing exceptions contained in this XDC file are scoped to xilinx_ram_sdp_lutram instances.
#       This file should be included using:
#       read_xdc -unmanaged -ref xilinx_ram_sdp_lutram <path-to-common-lib>/xilinx/ram/build/xilinx_ram_sdp_lutram/synth.xdc

# Set false path from write clock domain to read data registers
# NOTE: This constraint prevents these asynchronous paths from being timed, but the application
#       needs to make sure that this asynchronous crossing is handled properly.
#       The typical case here would be an asynchronous FIFO, which due to pointer synchronization
#       guarantees that the output data has settled when it is registered into the read clock domain.
set_false_path -quiet -from [get_clocks -quiet -of_objects [get_ports wr_clk]] -to [get_cells -quiet rd_data_reg[*]]
