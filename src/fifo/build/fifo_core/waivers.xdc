# Validation-only FIFO RAM payload waiver; load with read_xdc -ref fifo_core.
# Synchronized pointers prevent reading unwritten data and overwriting unread
# entries. Both domains must be initialized; callers disabling overflow or
# underflow protection must obey full/empty. See the FIFO README for the contract.
# Only distributed RAM write-clock -> read-data-register CDC-15 paths are waived.
# Generic RAM users, pointer synchronizers and read-address timing are excluded.
set fifo_ram_write_clocks [get_pins -quiet -hierarchical -filter {NAME =~ *i_mem_ram_sdp/i_xilinx_ram_sdp/g__lutram.i_xilinx_ram_sdp_lutram/mem_reg*/CLK || NAME =~ *i_mem_ram_sdp/i_xilinx_ram_sdp/g__lutram.i_xilinx_ram_sdp_lutram/mem_reg*/WCLK}]
set fifo_ram_read_data [get_pins -quiet -hierarchical -regexp {.*i_mem_ram_sdp/i_xilinx_ram_sdp/g__lutram\.i_xilinx_ram_sdp_lutram/rd_data_reg(\[[0-9]+\])?/D}]
# BRAM implementations have no matching pins. Quiet makes that a no-op;
# the OOC fixture verifies that these empty queries never create a waiver.
create_waiver -quiet -scoped -type CDC -id CDC-15 -user esnet \
    -description {FIFO distributed RAM payload protected by synchronized read/write pointers} \
    -from $fifo_ram_write_clocks -to $fifo_ram_read_data
