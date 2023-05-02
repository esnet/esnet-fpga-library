// Small, synchronous FIFO implementation, with single-cycle write-to-read latency
module fifo_small #(
    parameter type DATA_T = logic[15:0],
    parameter int  DEPTH = 4 // Intended for 'small' FIFOs
                             // Targets distributed RAM; depends on FPGA arch
                             // (typical max == 256),
) (
    // Clock/reset
    input  logic        clk,
    input  logic        srst,

    // Write interface
    input  logic        wr,
    input  DATA_T       wr_data,
    output logic        full,
    output logic        oflow,

    // Read interface
    input  logic        rd,
    output DATA_T       rd_data,
    output logic        empty,
    output logic        uflow
);
    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int PTR_WID = DEPTH > 1 ? $clog2(DEPTH) : 1;

    // -----------------------------
    // Signals
    // -----------------------------
    DATA_T mem [DEPTH];

    logic                 wr_safe;
    logic [PTR_WID-1:0]   wr_ptr;

    logic [PTR_WID-1:0]   rd_ptr;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf #() axil_if__unused ();

    // -----------------------------
    // Control FSM
    // -----------------------------
    fifo_ctrl_fsm  #(
        .DEPTH      ( DEPTH ),
        .ASYNC      ( 0 ),
        .OFLOW_PROT ( 1 ),
        .UFLOW_PROT ( 1 ),
        .WR_OPT_MODE( fifo_pkg::OPT_MODE_LATENCY ),
        .RD_OPT_MODE( fifo_pkg::OPT_MODE_LATENCY )
    ) i_fifo_ctrl_fsm (
        .wr_clk   ( clk ),
        .wr_srst  ( srst ),
        .wr_rdy   ( ),
        .wr       ( wr ),
        .wr_safe  ( wr_safe ),
        .wr_ptr   ( wr_ptr ),
        .wr_count ( ),
        .wr_full  ( full ),
        .wr_oflow ( oflow ),
        .rd_clk   ( clk ),
        .rd_srst  ( srst ),
        .rd       ( rd ),
        .rd_safe  ( ),
        .rd_ptr   ( rd_ptr ),
        .rd_count ( ),
        .rd_empty ( empty ),
        .rd_uflow ( uflow ),
        .mem_rdy  ( 1'b1 ),
        .axil_if  ( axil_if__unused )
    );

    // Write
    always_ff @(posedge clk) begin
        if (wr_safe) mem[wr_ptr] <= wr_data;
    end

    // Read
    assign rd_data = mem[rd_ptr];

    // Terminate unused AXI-L interface
    axi4l_intf_controller_term i_axi4l_intf_controller_term (.axi4l_if (axil_if__unused));

endmodule : fifo_small
