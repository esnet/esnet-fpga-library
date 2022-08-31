// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================
module state_valid_core #(
    parameter type ID_T = logic[15:0],
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1  // Optimize sim time by performing fast memory init
)(
    // Clock/reset
    input  logic             clk,
    input  logic             srst,

    output logic             init_done,

    // Control interface
    db_ctrl_intf.peripheral  ctrl_if
);
    // ----------------------------------
    // Imports
    // ----------------------------------
    import db_pkg::*;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int DEPTH = 2**$bits(ID_T);
    localparam int NUM_COLS = DEPTH > 4096 ? DEPTH / 4096 : 8;
    localparam int NUM_ROWS = DEPTH / NUM_COLS;
    localparam int MEM_RD_LATENCY = mem_pkg::get_default_rd_latency(NUM_ROWS, NUM_COLS);

    localparam int COL_SEL_WID = $clog2(NUM_COLS);
    localparam int ROW_SEL_WID = $clog2(NUM_ROWS);

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        logic [ROW_SEL_WID-1:0] row;
        logic [COL_SEL_WID-1:0] col;
    } id_t;

    typedef logic unused_t;

    typedef logic [COL_SEL_WID-1:0] col_sel_t;
    typedef logic [0:NUM_COLS-1] row_t;

    typedef struct packed {
        logic valid;
        id_t  id;
        logic wr;
        logic wr_value;
    } ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    ctxt_t ctxt_in;
    ctxt_t ctxt_out;

    id_t   id;

    logic  wr_rdy;
    row_t  wr_data;
    logic  wr_ack;

    logic  rd;
    logic  rd_rdy;
    logic  rd_valid;
    row_t  rd_data;
    logic  rd_ack;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    mem_intf #(.ADDR_WID(ROW_SEL_WID), .DATA_WID(NUM_COLS)) mem_wr_if (.clk(clk));
    mem_intf #(.ADDR_WID(ROW_SEL_WID), .DATA_WID(NUM_COLS)) mem_rd_if (.clk(clk));

    db_intf #(.KEY_T(id_t), .VALUE_T(unused_t)) ctrl_wr_if (.clk(clk));
    db_intf #(.KEY_T(id_t), .VALUE_T(unused_t)) ctrl_rd_if (.clk(clk));

    // ----------------------------------
    // Valid memory
    // ----------------------------------
    mem_ram_sdp_sync   #(
        .ADDR_WID       ( ROW_SEL_WID ),
        .DATA_WID       ( NUM_COLS ),
        .RESET_FSM      ( 1 ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_ram_sdp_sync_valid (
        .clk       ( clk ),
        .srst      ( srst ),
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if ),
        .init_done ( init_done )
    );

    // Memory read interface
    assign rd_rdy = mem_rd_if.rdy;
    assign mem_rd_if.rst  = 1'b0;
    assign mem_rd_if.en   = 1'b1;
    assign mem_rd_if.req  = ctrl_wr_if.req || ctrl_rd_if.req; // Writes must be implemented as RMW
    assign mem_rd_if.addr = id.row;
    assign rd_data = mem_rd_if.data;

    // Memory write interface
    assign wr_rdy = mem_rd_if.rdy;
    assign mem_wr_if.rst  = init;
    assign mem_wr_if.en   = ctxt_out.wr;
    assign mem_wr_if.req  = mem_rd_if.ack;
    assign mem_wr_if.addr = ctxt_out.id.row;
    assign mem_wr_if.data = wr_data;

    // -----------------------------
    // Transaction handling
    // (use 'standard' database peripheral component)
    // -----------------------------
    db_ctrl_peripheral i_db_ctrl_peripheral (
        .clk       ( clk ),
        .srst      ( srst ),
        .ctrl_if   ( ctrl_if ),
        .init      ( init ),
        .init_done ( init_done ),
        .wr_if     ( ctrl_wr_if ),
        .rd_if     ( ctrl_rd_if )
    );
    assign id = ctrl_wr_if.req ? ctrl_wr_if.key : ctrl_rd_if.key;

    assign ctrl_wr_if.rdy = wr_rdy;
    assign ctrl_wr_if.ack = wr_ack;
    assign ctrl_wr_if.error = 1'b0;
    assign ctrl_wr_if.ack_id = '0;

    assign ctrl_rd_if.rdy = rd_rdy;
    assign ctrl_rd_if.ack = rd_ack;
    assign ctrl_rd_if.error = 1'b0;
    assign ctrl_rd_if.ack_id = '0;
    assign ctrl_rd_if.valid = rd_valid;
    assign ctrl_rd_if.value = '0; // Unused (no value, 'valid' tracking only)

    // RMW context
    assign ctxt_in.valid = ctrl_wr_if.req || ctrl_rd_if.req;
    assign ctxt_in.id = id;
    assign ctxt_in.wr = ctrl_wr_if.req;
    assign ctxt_in.wr_value = ctrl_wr_if.valid;

    util_delay   #(
        .DATA_T   ( ctxt_t ),
        .DELAY    ( MEM_RD_LATENCY )
    ) i_rd_ctxt_util_delay (
        .clk      ( clk ),
        .srst     ( srst ),
        .data_in  ( ctxt_in ),
        .data_out ( ctxt_out )
    );

    // Write valid status for specified entry
    always_comb begin
        wr_data = rd_data;
        wr_data[ctxt_out.id.col] = ctxt_out.wr_value;
    end

    // Extract valid status for specified entry
    always_comb begin
        rd_valid = rd_data[ctxt_out.id.col];
    end

    // Ack
    assign rd_ack = ctxt_out.valid;
    assign rd_error = (ctxt_out.valid && !ctxt_out.wr && !mem_rd_if.ack);

    assign wr_ack = ctxt_out.wr;
    assign wr_error = (ctxt_out.valid && ctxt_out.wr && !mem_rd_if.ack);

endmodule : state_valid_core
