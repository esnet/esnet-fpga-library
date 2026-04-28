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
    logic [DATA_WID-1:0] data;
    logic valid;
    logic ready;

    fec_meta_t meta;

    localparam int META_WID = $bits(meta);

    // Modports
    modport tx (
        input  clk,
        output data,
        output valid,
        input  ready,
        output meta
    );

    modport rx (
        input  clk,
        input  data,
        input  valid,
        output ready,
        input  meta
    );

endinterface : rs_acc_intf
