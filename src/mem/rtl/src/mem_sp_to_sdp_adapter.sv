// Single-Port (SP) to Simple Dual-Port (SDP) interface adapter
// NOTE: This module converts a monolithic single-port memory interface (mem_intf)
//       into separate (synchronous) write and read interfaces (mem_wr_intf/mem_rd_intf).
module mem_sp_to_sdp_adapter (
    // Memory interface
    mem_intf.peripheral mem_if,

    // SDP write/read interfaces
    mem_wr_intf.controller mem_wr_if,
    mem_rd_intf.controller mem_rd_if
);

    // Convert from monolithic memory interface to
    // separate read/write memory interfaces (i.e. SDP)
    assign mem_if.rdy = (mem_wr_if.rdy && mem_rd_if.rdy);

    assign mem_wr_if.rst = mem_if.rst;
    assign mem_wr_if.en = 1'b1;
    assign mem_wr_if.req = mem_if.req && mem_if.wr;
    assign mem_wr_if.addr = mem_if.addr;
    assign mem_wr_if.data = mem_if.wr_data;
    assign mem_if.wr_ack = mem_wr_if.ack;

    assign mem_rd_if.rst = mem_if.rst;
    assign mem_rd_if.req = mem_if.req && !mem_if.wr;
    assign mem_rd_if.addr = mem_if.addr;
    assign mem_if.rd_ack = mem_rd_if.ack;
    assign mem_if.rd_data = mem_rd_if.data;

endmodule : mem_sp_to_sdp_adapter
