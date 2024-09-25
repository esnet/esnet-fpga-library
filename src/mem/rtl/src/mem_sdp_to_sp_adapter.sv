// Simple Dual-Port (SDP) to Single-Port (SP) interface adapter
// NOTE: This module converts separate (synchronous) write and read interfaces
//       (mem_wr_intf/mem_rd_intf) to a monolithic single-port memory interface
//       (mem_intf).
module mem_sdp_to_sp_adapter #(
    parameter bit WRITE_PRIORITY = 1 // When set, give strict priority to writes (when both wr/rd interfaces have active requests)
                                     // When unset, give strict priority to reads
) (
    // SDP write/read interfaces
    mem_wr_intf.peripheral mem_wr_if,
    mem_rd_intf.peripheral mem_rd_if,

    // Memory interface
    mem_intf.controller mem_if
);
    // Signals
    logic wr_req;
    logic rd_req;

    assign wr_req = mem_wr_if.en && mem_wr_if.req;
    assign rd_req = mem_rd_if.req;

    // Convert from separate read/write memory interfaces (i.e. SDP)
    // to a (monolithic) single-port interface
    assign mem_if.rst = mem_wr_if.rst;
    assign mem_if.req = wr_req || rd_req;
    
    generate
        if (WRITE_PRIORITY) begin : g__wr_prio
            assign mem_wr_if.rdy = mem_if.rdy;
            assign mem_rd_if.rdy = mem_if.rdy && !wr_req;
            assign mem_if.wr = wr_req;
            assign mem_if.addr = wr_req ? mem_wr_if.addr : mem_rd_if.addr;
        end : g__wr_prio
        else begin : g__rd_prio
            assign mem_wr_if.rdy = mem_if.rdy && !rd_req;
            assign mem_rd_if.rdy = mem_if.rdy;
            assign mem_if.wr = wr_req && !rd_req;
            assign mem_if.addr = rd_req ? mem_rd_if.addr : mem_wr_if.addr;
        end : g__rd_prio
    endgenerate
    assign mem_if.wr_data = mem_wr_if.data;
    assign mem_wr_if.ack = mem_if.wr_ack;

    assign mem_rd_if.ack = mem_if.rd_ack;
    assign mem_rd_if.data = mem_if.rd_data;

endmodule : mem_sdp_to_sp_adapter
