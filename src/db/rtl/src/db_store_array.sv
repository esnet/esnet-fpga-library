module db_store_array #(
    parameter int  KEY_WID = 1,
    parameter int  VALUE_WID = 1,
    parameter bit  TRACK_VALID = 1,// When set, each record includes a valid bit
                                   // When unset, records do not include a valid bit (all records are considered valid)
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1, // Optimize sim time by performing fast memory init
    parameter bit  SIM__RAM_MODEL = 0
)(
    // Clock/reset
    input  logic            clk,
    input  logic            srst,

    input  logic            init,
    output logic            init_done,

    // Database write/read interfaces
    db_intf.responder       db_wr_if,
    db_intf.responder       db_rd_if
);
    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int ENTRY_WID = TRACK_VALID ? VALUE_WID + 1 : VALUE_WID;

    // Check
    initial begin
        std_pkg::param_check_gt(db_wr_if.KEY_WID,   KEY_WID,   "db_wr_if.KEY_WID");
        std_pkg::param_check(db_wr_if.VALUE_WID, VALUE_WID, "db_wr_if.VALUE_WID");
        std_pkg::param_check_gt(db_rd_if.KEY_WID,   KEY_WID,   "db_rd_if.KEY_WID");
        std_pkg::param_check(db_rd_if.VALUE_WID, VALUE_WID, "db_rd_if.VALUE_WID");
    end

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    mem_wr_intf #(.ADDR_WID(KEY_WID), .DATA_WID(ENTRY_WID)) mem_wr_if (.clk(clk));
    mem_rd_intf #(.ADDR_WID(KEY_WID), .DATA_WID(ENTRY_WID)) mem_rd_if (.clk(clk));

    // ----------------------------------
    // Init done
    // ----------------------------------
    assign init_done = mem_wr_if.rdy;

    // ----------------------------------
    // Database memory
    // ----------------------------------
    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: KEY_WID,
        DATA_WID: ENTRY_WID,
        ASYNC: 0,
        RESET_FSM: 1,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    mem_ram_sdp        #(
        .SPEC           ( MEM_SPEC ),
        .SIM__FAST_INIT ( SIM__FAST_INIT ),
        .SIM__RAM_MODEL ( SIM__RAM_MODEL )
    ) i_mem_ram_sdp__db (
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if )
    );

    // ----------------------------------
    // Drive memory write interface
    // ----------------------------------
    assign mem_wr_if.rst  = srst | init;
    assign mem_wr_if.en   = 1'b1;
    assign mem_wr_if.req  = db_wr_if.req;
    assign mem_wr_if.addr = db_wr_if.key;
    assign db_wr_if.rdy = mem_wr_if.rdy;
    assign db_wr_if.ack = mem_wr_if.ack;
    assign db_wr_if.error = 1'b0;
    assign db_wr_if.next_key = '0;

    assign mem_rd_if.rst  = 1'b0;
    assign mem_rd_if.req  = db_rd_if.req;
    assign mem_rd_if.addr = db_rd_if.key;
    assign db_rd_if.rdy = mem_rd_if.rdy;
    assign db_rd_if.ack = mem_rd_if.ack;
    assign db_rd_if.error = 1'b0;
    assign db_rd_if.next_key = '0;

    generate
        if (TRACK_VALID) begin : g__valid_tracked
            assign mem_wr_if.data = {db_wr_if.valid, db_wr_if.value};
            assign {db_rd_if.valid, db_rd_if.value} = mem_rd_if.data;
        end : g__valid_tracked
        else begin : g__valid_untracked
            assign mem_wr_if.data = {db_wr_if.value};
            assign db_rd_if.valid = 1'b1;
            assign db_rd_if.value = mem_rd_if.data;
        end : g__valid_untracked
    endgenerate

endmodule : db_store_array
