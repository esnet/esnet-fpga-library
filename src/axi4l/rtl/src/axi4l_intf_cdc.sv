module axi4l_intf_cdc
    import axi4l_pkg::*;
#(
    parameter int ADDR_WID = 32,
    parameter axi4l_bus_width_t BUS_WIDTH = AXI4L_BUS_WIDTH_32
) (
    axi4l_intf.peripheral axi4l_if_from_controller,
    input logic           clk_to_peripheral,
    axi4l_intf.controller axi4l_if_to_peripheral
);
    // Parameters
    localparam int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH);
    localparam int DATA_WID = DATA_BYTE_WID * 8;

    // Typedefs
    typedef logic [ADDR_WID-1:0]      addr_t;
    typedef logic [DATA_WID-1:0]      data_t;
    typedef logic [DATA_BYTE_WID-1:0] strb_t;

    typedef struct packed {
        addr_t addr;
        data_t data;
        strb_t strb;
    } wr_req_ctxt_t;

    typedef struct packed {
        data_t data;
        resp_t resp;
    } rd_resp_ctxt_t;

    // Signals
    logic   clk__from_controller;
    logic   srst__from_controller;

    logic   wr__from_controller;
    addr_t  wr_addr__from_controller;
    data_t  wr_data__from_controller;
    strb_t  wr_strb__from_controller;
    logic   wr_ack__to_controller;
    resp_t  wr_resp__to_controller;
    logic   rd__from_controller;
    addr_t  rd_addr__from_controller;
    data_t  rd_data__to_controller;
    logic   rd_ack__to_controller;
    resp_t  rd_resp__to_controller;
    
    logic   clk__to_peripheral;
    logic   srst__to_peripheral;
    logic   wr__to_peripheral;
    addr_t  wr_addr__to_peripheral;
    data_t  wr_data__to_peripheral;
    strb_t  wr_strb__to_peripheral;
    logic   wr_ack__from_peripheral;
    resp_t  wr_resp__from_peripheral;
    logic   rd__to_peripheral;
    addr_t  rd_addr__to_peripheral;
    data_t  rd_data__from_peripheral;
    logic   rd_ack__from_peripheral;
    resp_t  rd_resp__from_peripheral;

    // Terminate interface from controller
    axi4l_peripheral #(
        .ADDR_WID  ( ADDR_WID ),
        .BUS_WIDTH ( BUS_WIDTH )
    ) i_axi4l_peripheral (
        .axi4l_if  ( axi4l_if_from_controller ),
        .clk       ( clk__from_controller ),
        .srst      ( srst__from_controller ),
        .wr        ( wr__from_controller ),
        .wr_addr   ( wr_addr__from_controller ),
        .wr_data   ( wr_data__from_controller ),
        .wr_strb   ( wr_strb__from_controller ),
        .wr_ack    ( wr_ack__to_controller ),
        .wr_resp   ( wr_resp__to_controller ),
        .rd        ( rd__from_controller ),
        .rd_addr   ( rd_addr__from_controller ),
        .rd_data   ( rd_data__to_controller ),
        .rd_ack    ( rd_ack__to_controller ),
        .rd_resp   ( rd_resp__to_controller )
    );

    // Clock renamed for consistency
    assign clk__to_peripheral = clk_to_peripheral;

    // Retime reset into output domain
    sync_reset #(
        .INPUT_ACTIVE_HIGH ( 1 )
    ) i_sync_reset (
        .clk_in  ( clk__from_controller ),
        .rst_in  ( srst__from_controller ),
        .clk_out ( clk__to_peripheral ),
        .rst_out ( srst__to_peripheral )
    );

    // Synchronize individual transaction interfaces

    // - Write request
    wr_req_ctxt_t wr_req_ctxt__from_controller;
    wr_req_ctxt_t wr_req_ctxt__to_peripheral;
    
    assign wr_req_ctxt__from_controller.addr = wr_addr__from_controller;
    assign wr_req_ctxt__from_controller.data = wr_data__from_controller;
    assign wr_req_ctxt__from_controller.strb = wr_strb__from_controller;

    sync_bus #(
        .DATA_WID ( $bits(wr_req_ctxt_t) ),
        .HANDSHAKE_MODE ( sync_pkg::HANDSHAKE_MODE_2PHASE )
    ) i_sync_bus__wr_req (
        .clk_in ( clk__from_controller ),
        .rst_in ( srst__from_controller ),
        .rdy_in ( ),
        .req_in ( wr__from_controller ),
        .data_in ( wr_req_ctxt__from_controller ),
        .clk_out ( clk__to_peripheral ),
        .rst_out ( srst__to_peripheral ),
        .ack_out ( wr__to_peripheral ),
        .data_out ( wr_req_ctxt__to_peripheral )
    );
    assign wr_addr__to_peripheral = wr_req_ctxt__to_peripheral.addr;
    assign wr_data__to_peripheral = wr_req_ctxt__to_peripheral.data;
    assign wr_strb__to_peripheral = wr_req_ctxt__to_peripheral.strb;

    // - Write response
    sync_bus #(
        .DATA_WID ( $bits(resp_t) ),
        .HANDSHAKE_MODE ( sync_pkg::HANDSHAKE_MODE_2PHASE )
    ) i_sync_bus__wr_resp (
        .clk_in ( clk__to_peripheral ),
        .rst_in ( srst__to_peripheral ),
        .rdy_in ( ),
        .req_in ( wr_ack__from_peripheral ),
        .data_in ( wr_resp__from_peripheral ),
        .clk_out ( clk__from_controller ),
        .rst_out ( srst__from_controller ),
        .ack_out ( wr_ack__to_controller ),
        .data_out ( wr_resp__to_controller )
    );

    // - Read request
    sync_bus #(
        .DATA_WID ( $bits(addr_t) ),
        .HANDSHAKE_MODE ( sync_pkg::HANDSHAKE_MODE_2PHASE )
    ) i_sync_bus__rd_req (
        .clk_in ( clk__from_controller ),
        .rst_in ( srst__from_controller ),
        .rdy_in ( ),
        .req_in ( rd__from_controller ),
        .data_in ( rd_addr__from_controller ),
        .clk_out ( clk__to_peripheral ),
        .rst_out ( srst__to_peripheral ),
        .ack_out ( rd__to_peripheral ),
        .data_out ( rd_addr__to_peripheral )
    );

    // - Read response
    rd_resp_ctxt_t rd_resp_ctxt__from_peripheral;
    rd_resp_ctxt_t rd_resp_ctxt__to_controller;
    
    assign rd_resp_ctxt__from_peripheral.data = rd_data__from_peripheral;
    assign rd_resp_ctxt__from_peripheral.resp = rd_resp__from_peripheral;

    sync_bus #(
        .DATA_WID ( $bits(rd_resp_ctxt_t) ),
        .HANDSHAKE_MODE ( sync_pkg::HANDSHAKE_MODE_2PHASE )
    ) i_sync_bus__rd_resp (
        .clk_in ( clk__to_peripheral ),
        .rst_in ( srst__to_peripheral ),
        .rdy_in ( ),
        .req_in ( rd_ack__from_peripheral ),
        .data_in ( rd_resp_ctxt__from_peripheral ),
        .clk_out ( clk__from_controller ),
        .rst_out ( srst__from_controller ),
        .ack_out ( rd_ack__to_controller ),
        .data_out ( rd_resp_ctxt__to_controller )
    );
    assign rd_data__to_controller = rd_resp_ctxt__to_controller.data;
    assign rd_resp__to_controller = rd_resp_ctxt__to_controller.resp;

    // Terminate interface to peripheral
    axi4l_controller #(
        .ADDR_WID   ( ADDR_WID ),
        .BUS_WIDTH  ( BUS_WIDTH ),
        .WR_TIMEOUT ( 0 ), // Disable write timeouts
        .RD_TIMEOUT ( 0 )  // Disable read timeouts
    ) i_axi4l_controller (
        .clk       ( clk__to_peripheral ),
        .srst      ( srst__to_peripheral ),
        .wr        ( wr__to_peripheral ),
        .wr_addr   ( wr_addr__to_peripheral ),
        .wr_data   ( wr_data__to_peripheral ),
        .wr_strb   ( wr_strb__to_peripheral ),
        .wr_ack    ( wr_ack__from_peripheral ),
        .wr_resp   ( wr_resp__from_peripheral ),
        .rd        ( rd__to_peripheral ),
        .rd_addr   ( rd_addr__to_peripheral ),
        .rd_data   ( rd_data__from_peripheral ),
        .rd_ack    ( rd_ack__from_peripheral ),
        .rd_resp   ( rd_resp__from_peripheral ),
        .axi4l_if  ( axi4l_if_to_peripheral )
    );

endmodule : axi4l_intf_cdc

