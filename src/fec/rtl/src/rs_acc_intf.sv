interface rs_acc_intf
    import fec_pkg::*;
#(
    parameter int DATA_WID = 1,
    parameter int COL_LEN  = 1,
    // Derived parameters (don't override)                                                                                       
    parameter int CLKS_PER_BLK = RS_K * SYM_SIZE * COL_LEN / DATA_WID
) (
    input logic clk
);

    // Parameter validation
    initial begin
        std_pkg::param_check_gt(DATA_WID, 1, "DATA_WID");
        std_pkg::param_check_gt(COL_LEN,  1, "COL_LEN" );
    end


    // Signals
    logic valid;
    logic ready;
    logic [DATA_WID-1:0] data;
    logic [$clog2(CLKS_PER_BLK)-1:0] blk_size;


    // Modports
    modport tx (
        input  clk,
        output valid,
        input  ready,
        output data,
        output blk_size
    );

    modport rx (
        input  clk,
        input  valid,
        output ready,
        input  data,
        input  blk_size
    );

endinterface : rs_acc_intf
