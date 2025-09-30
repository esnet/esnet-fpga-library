// Bus interface pipeline stage
//
// Includes register stages and a pipelining FIFO receiver stage
// to accommodate the required number of stages of slack in
// valid <-> ready handshaking protocol
module bus_pipe #(
    parameter int  STAGES = 1 // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
) (
    bus_intf.rx   from_tx,
    bus_intf.tx   to_rx
);
    // Parameters
    localparam int  TOTAL_SLACK = 2*STAGES;
    localparam int  DATA_WID = from_tx.DATA_WID;

    // Parameter check
    initial begin
        std_pkg::param_check(from_tx.DATA_WID, to_rx.DATA_WID, "DATA_WID");
        std_pkg::param_check_gt(STAGES, 1, "STAGES");
    end

    // Clock/reset
    logic clk;
    logic srst;

    assign clk = from_tx.clk;
    assign srst = from_tx.srst;

    // Interfaces
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__tx (.clk, .srst);
    bus_intf #(.DATA_WID(DATA_WID)) bus_if__rx (.clk, .srst);

    // Evaluate valid <-> ready handshake at input
    assign bus_if__tx.valid = from_tx.valid && bus_if__tx.ready;
    assign bus_if__tx.data = from_tx.data;
    assign from_tx.ready = bus_if__tx.ready;

    // Add pipeline stages as specified
    bus_reg_multi    #(
        .STAGES       ( STAGES )
    ) i_bus_reg_multi (
        .from_tx ( bus_if__tx ),
        .to_rx   ( bus_if__rx )
    );
    
    // Implement Rx FIFO to accommodate specified slack
    // in valid <-> ready handshake protocol
    fifo_prefetch #(
        .DATA_WID  ( DATA_WID ),
        .PIPELINE_DEPTH ( TOTAL_SLACK )
    ) i_fifo_prefetch (
        .clk,
        .srst,
        .wr      ( bus_if__rx.valid ),
        .wr_rdy  ( bus_if__rx.ready ),
        .wr_data ( bus_if__rx.data ),
        .oflow   ( ),
        .rd      ( to_rx.ready ),
        .rd_vld  ( to_rx.valid ),
        .rd_data ( to_rx.data )
    );

endmodule : bus_pipe
