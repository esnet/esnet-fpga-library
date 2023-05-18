module fifo_async #(
    parameter type DATA_T = logic[15:0],
    parameter int DEPTH = 32,
    parameter bit FWFT = 1,
    parameter bit OFLOW_PROT = 1,
    parameter bit UFLOW_PROT = 1,
    // Derived parameters (don't override)
    parameter int  CNT_WID = FWFT ? $clog2(DEPTH+1+1) : $clog2(DEPTH+1),
    // Debug parameters
    parameter bit DEBUG_ILA = 1'b0
) (
    // Write interface
    input  logic               wr_clk,
    input  logic               wr_srst,
    output logic               wr_rdy,
    input  logic               wr,
    input  DATA_T              wr_data,

    // Read interface
    input  logic               rd_clk,
    input  logic               rd_srst,
    input  logic               rd,
    output logic               rd_ack,
    output DATA_T              rd_data,

    // Status
    output logic [CNT_WID-1:0] wr_count,
    output logic [CNT_WID-1:0] rd_count,
    output logic               full,
    output logic               empty,

    output logic               oflow,
    output logic               uflow
);

    // -----------------------------
    // Signals
    // -----------------------------
    logic [31:0] __wr_count;
    logic [31:0] __rd_count;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf axil_if__unused ();

    // -----------------------------
    // Instantiate FIFO core
    // -----------------------------
    fifo_core #(
        .DATA_T ( DATA_T ),
        .DEPTH  ( DEPTH ),
        .ASYNC  ( 1 ),
        .FWFT   ( FWFT ),
        .OFLOW_PROT ( OFLOW_PROT ),
        .UFLOW_PROT ( UFLOW_PROT ),
        .AXIL_IF    ( 0 ),
        .DEBUG_ILA  ( DEBUG_ILA )
    ) i_fifo_core (
        .wr_clk   ( wr_clk ),
        .wr_srst  ( wr_srst ),
        .wr_rdy   ( wr_rdy ),
        .wr       ( wr ),
        .wr_data  ( wr_data ),
        .wr_count ( __wr_count ),
        .wr_full  ( full ),
        .wr_oflow ( oflow ),
        .rd_clk   ( rd_clk ),
        .rd_srst  ( rd_srst ),
        .rd       ( rd ),
        .rd_ack   ( rd_ack ),
        .rd_data  ( rd_data ),
        .rd_count ( __rd_count ),
        .rd_empty ( empty ),
        .rd_uflow ( uflow ),
        .axil_if  ( axil_if__unused )
    );

    assign wr_count = __wr_count[CNT_WID-1:0];
   
    initial rd_count = 0;
    always @(posedge rd_clk) begin
        if (rd_srst) rd_count <= 0;
        else         rd_count <= __rd_count[CNT_WID-1:0];
    end
   
    // Tie off (unused AXI-L interface)
    axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if(axil_if__unused));
    
endmodule : fifo_async
