module packet_fifo_sync_wrapper #(
    parameter int DEPTH = 512,
    parameter int DATA_BYTE_WID = 64,
    parameter int META_WID = 32,
    // Derived parameters (don't override)
    parameter int DATA_WID = DATA_BYTE_WID * 8,
    parameter int MTY_WID = $clog2(DATA_BYTE_WID)
)(
    input  logic                 clk,
    input  logic                 srst,

    input  logic                 packet_in_valid,
    output logic                 packet_in_rdy,
    input  logic                 packet_in_eop,
    input  logic [DATA_WID-1:0]  packet_in_data,
    input  logic [MTY_WID-1:0]   packet_in_mty,
    input  logic                 packet_in_err,
    input  logic [META_WID-1:0]  packet_in_meta,

    output logic                 packet_out_valid,
    input  logic                 packet_out_rdy,
    output logic                 packet_out_eop,
    output logic [DATA_WID-1:0]  packet_out_data,
    output logic [MTY_WID-1:0]   packet_out_mty,
    output logic                 packet_out_err,
    output logic [META_WID-1:0]  packet_out_meta
);

    localparam type META_T = logic[META_WID-1:0];

    packet_intf #(DATA_BYTE_WID, META_T) packet_in_if  (.clk(clk), .srst(srst));
    packet_intf #(DATA_BYTE_WID, META_T) packet_out_if (.clk(clk), .srst(srst));

    assign packet_in_if.valid = packet_in_valid;
    assign packet_in_if.eop = packet_in_eop;
    assign packet_in_if.data = packet_in_data;
    assign packet_in_if.mty = packet_in_mty;
    assign packet_in_if.err = packet_in_err;
    assign packet_in_if.meta = packet_in_meta;
    assign packet_in_rdy = packet_in_if.rdy;

    assign packet_out_valid = packet_out_if.valid;
    assign packet_out_eop = packet_out_if.eop;
    assign packet_out_data = packet_out_if.data;
    assign packet_out_mty = packet_out_if.mty;
    assign packet_out_err = packet_out_if.err;
    assign packet_out_meta = packet_out_if.meta;
    assign packet_out_if.rdy = packet_out_rdy;

    packet_fifo #(
        .ASYNC   ( 0 ),
        .DEPTH   ( DEPTH )
    ) i_packet_fifo (
        .*
    );

endmodule : packet_fifo_sync_wrapper
