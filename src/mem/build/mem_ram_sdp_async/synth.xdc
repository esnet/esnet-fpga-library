# ===================================================
# CDC timing exceptions for mem_ram_sdp_async
# ===================================================
# NOTE: Timing exceptions contained in this XDC file are scoped to mem_ram_sdp_async instances.
#       This file should be included using:
#       read_xdc -unmanaged -ref mem_ram_sdp_async <path-to-common-lib>/mem/build/mem_ram_sdp_async/synth.xdc

# Set false path from write clock domain to read data registers
# NOTE 1: Applies only to distributed RAM implementations.
# NOTE 2: This constraint prevents these asynchronous paths from being timed, but the application
#         needs to make sure that this asynchronous crossing is handled properly.
#         The typical case here would be an asynchronous FIFO, which due to pointer synchronization
#         guarantees that the output data has settled when it is registered into the read clock domain.
set_false_path -quiet -from [get_clocks -quiet -of_objects [get_ports wr_clk]] -to [get_cells -quiet i_mem_ram_sdp_core/rd_data_reg[*]]
