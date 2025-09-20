module packet_gather_wrapper #(
    parameter int MAX_PKT_SIZE = 16384,
    parameter int BUFFER_SIZE = 2048,
    parameter int PTR_WID = 20,
    parameter int DATA_BYTE_WID = 32,
    parameter int META_WID = 5,
    // Derived parameters (don't override)
    parameter int DATA_WID = DATA_BYTE_WID * 8,
    parameter int MTY_WID = $clog2(DATA_BYTE_WID),
    parameter int SIZE_WID = $clog2(BUFFER_SIZE),
    parameter int ADDR_WID = PTR_WID + $clog2(BUFFER_SIZE/DATA_BYTE_WID),
    parameter int PKT_SIZE_WID = $clog2(MAX_PKT_SIZE+1)
)(
    input  logic                 clk,
    input  logic                 srst,

    output logic                 packet_vld,
    input  logic                 packet_rdy,
    output logic                 packet_eop,
    output logic [DATA_WID-1:0]  packet_data,
    output logic [MTY_WID-1:0]   packet_mty,
    output logic                 packet_err,
    output logic [META_WID-1:0]  packet_meta,

    output logic                 gather_req,
    input  logic                 gather_rdy,
    output logic [PTR_WID-1:0]   gather_ptr,
    input  logic [PTR_WID-1:0]   gather_nxt_ptr,
    input  logic                 gather_vld,
    output logic                 gather_ack,
    input  logic                 gather_eof,
    input  logic [SIZE_WID-1:0]  gather_size,
    input  logic [META_WID-1:0]  gather_meta,
    input  logic                 gather_err,
    input  logic                 gather_sof,

    input  logic                 descriptor_vld,
    output logic                 descriptor_rdy,
    input  logic [PTR_WID-1:0]   descriptor_addr,
    input  logic [PKT_SIZE_WID-1:0] descriptor_size,
    input  logic                 descriptor_err,
    input  logic [META_WID-1:0]  descriptor_meta,

    output logic                 packet_event_evt,
    output logic [31:0]          packet_event_size,
    output logic [2:0]           packet_event_status,

    output logic                 mem_rd_rst,
    input  logic                 mem_rd_rdy,
    output logic                 mem_rd_req,
    output logic [ADDR_WID-1:0]  mem_rd_addr,
    input  logic [DATA_WID-1:0]  mem_rd_data,
    input  logic                 mem_rd_ack,

    input  logic                 mem_init_done

);

    localparam int NUM_BUFFERS = 2**PTR_WID;

    packet_intf #(DATA_BYTE_WID, META_WID) packet_if  (.clk, .srst);
    alloc_intf #(BUFFER_SIZE, PTR_WID, META_WID) gather_if (.clk, .srst);
    packet_descriptor_intf #(PTR_WID, META_WID, MAX_PKT_SIZE) descriptor_if (.clk, .srst);
    packet_event_intf event_if (.clk);
    mem_rd_intf #(ADDR_WID, DATA_WID) mem_rd_if (.clk);

    assign packet_vld = packet_if.vld;
    assign packet_eop = packet_if.eop;
    assign packet_data = packet_if.data;
    assign packet_mty = packet_if.mty;
    assign packet_err = packet_if.err;
    assign packet_meta = packet_if.meta;
    assign packet_if.rdy = packet_rdy;

    assign gather_if.rdy = gather_rdy;
    assign gather_if.nxt_ptr = gather_nxt_ptr;
    assign gather_if.vld = gather_vld;
    assign gather_if.eof = gather_eof;
    assign gather_if.size = gather_size;
    assign gather_if.meta = gather_meta;
    assign gather_if.err = gather_err;
    assign gather_if.sof = gather_sof;
    assign gather_req = gather_if.req;
    assign gather_ptr = gather_if.ptr;
    assign gather_ack = gather_if.ack;

    assign descriptor_if.vld = descriptor_vld;
    assign descriptor_if.addr = descriptor_addr;
    assign descriptor_if.size = descriptor_size;
    assign descriptor_if.err = descriptor_err;
    assign descriptor_if.meta = descriptor_meta;
    assign descriptor_rdy = descriptor_if.rdy;

    assign packet_event_evt = event_if.evt;
    assign packet_event_size = event_if.size;
    assign packet_event_status = event_if.status;

    assign mem_rd_if.rdy = mem_rd_rdy;
    assign mem_rd_if.data = mem_rd_data;
    assign mem_rd_if.ack = mem_rd_ack;
    assign mem_rd_rst = mem_rd_if.rst;
    assign mem_rd_req = mem_rd_if.req;
    assign mem_rd_addr = mem_rd_if.addr;

    packet_gather    #(
        .IGNORE_RDY   ( 0 ),
        .MAX_PKT_SIZE ( MAX_PKT_SIZE ),
        .BUFFER_SIZE  ( BUFFER_SIZE ),
        .NUM_BUFFERS  ( NUM_BUFFERS ),
        .MAX_RD_LATENCY ( 64 )
    ) i_packet_gather (
        .*
    );

endmodule : packet_gather_wrapper
