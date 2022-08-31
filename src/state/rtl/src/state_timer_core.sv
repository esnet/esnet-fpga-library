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
module state_timer_core #(
    parameter type ID_T = logic[15:0],
    parameter type TIMER_T = logic[15:0],
    parameter bit  RESET_FSM = 1, // When set,   reset FSM is included to clear (zero) timer memory on reset
                                  // When unset, reset FSM is not included (memory contents unchanged on reset)
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
)(
    // Clock/reset
    input  logic            clk,
    input  logic            srst,

    output logic            init_done,

    // Timestamp
    input  logic            tick,

    // Control interface
    db_intf.responder       read_if,

    // Update interface
    db_intf.responder       update_if
);
    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int ID_WID = $bits(ID_T);
    localparam int TIMER_WID = $bits(TIMER_T);
    localparam int DEPTH = 2**ID_WID;
    localparam int MEM_RD_LATENCY = mem_pkg::get_default_rd_latency(DEPTH, TIMER_WID);

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef struct packed {
        logic update_req;
        logic read_req;
    } rd_ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    rd_ctxt_t  rd_ctxt_in;
    rd_ctxt_t  rd_ctxt_out;

    logic      update_ack;
    logic      read_ack;
    
    TIMER_T    timer;
    TIMER_T    rd_timer;
    TIMER_T    ts_delta;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    mem_intf #(.ADDR_WID(ID_WID), .DATA_WID(TIMER_WID)) mem_wr_if (.clk(clk));
    mem_intf #(.ADDR_WID(ID_WID), .DATA_WID(TIMER_WID)) mem_rd_if (.clk(clk));

    // ----------------------------------
    // Timer memory
    // ----------------------------------
    mem_ram_sdp_sync #(
        .ADDR_WID  ( ID_WID ),
        .DATA_WID  ( TIMER_WID ),
        .RESET_FSM ( RESET_FSM ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_ram_sdp_sync_timer (
        .clk       ( clk ),
        .srst      ( srst ),
        .mem_wr_if ( mem_wr_if ),
        .mem_rd_if ( mem_rd_if ),
        .init_done ( init_done )
    );

    // ----------------------------------
    // Timer
    // ----------------------------------
    initial timer = 0;
    always @(posedge clk) begin
        if (srst)      timer <= 0;
        else if (tick) timer <= timer + 1;
    end

    // ----------------------------------
    // Drive memory write interface
    // ----------------------------------
    assign mem_wr_if.rst  = 1'b0;
    assign mem_wr_if.en   = 1'b1;
    assign mem_wr_if.req  = update_if.req;
    assign mem_wr_if.addr = update_if.key;
    assign mem_wr_if.data = timer;

    // ----------------------------------
    // Drive memory read interface
    // ----------------------------------
    assign mem_rd_if.rst  = 1'b0;
    assign mem_rd_if.en   = 1'b1;
    assign mem_rd_if.req  = update_if.req || read_if.req;
    assign mem_rd_if.addr = update_if.req ? update_if.key : read_if.key;
    assign rd_timer = mem_rd_if.data;
    
    // ----------------------------------
    // Calculate time since last update
    // ----------------------------------
    always_ff @(posedge clk) if (mem_rd_if.ack) ts_delta <= (timer - rd_timer);

    // -----------------------------
    // Read context pipeline
    // -----------------------------
    assign rd_ctxt_in.read_req   = read_if.req && !update_if.req;
    assign rd_ctxt_in.update_req = update_if.req;

    util_delay   #(
        .DATA_T   ( rd_ctxt_t),
        .DELAY    ( MEM_RD_LATENCY )
    ) i_rd_ctxt_util_delay (
        .clk      ( clk ),
        .srst     ( srst ),
        .data_in  ( rd_ctxt_in ),
        .data_out ( rd_ctxt_out )
    );

    // Demux between update/read interfaces and delay to account for delta calculation
    initial begin
        update_ack = 1'b0;
        read_ack = 1'b0;
    end
    always @(posedge clk) begin
        if (srst) begin
            update_ack <= 1'b0;
            read_ack <= 1'b0;
        end else begin
            update_ack <= rd_ctxt_out.update_req;
            read_ack   <= rd_ctxt_out.read_req;
        end
    end
    
    // -----------------------------
    // Assign update interface outputs
    // -----------------------------
    assign update_if.rdy = init_done;
    assign update_if.ack = update_ack;
    assign update_if.ack_id = '0;
    assign update_if.valid = 1'b1;
    assign update_if.value = ts_delta;

    // -----------------------------
    // Assign read interface outputs
    // -----------------------------
    assign read_if.rdy = init_done && !update_if.req;
    assign read_if.ack = read_ack;
    assign read_if.ack_id = '0;
    assign read_if.valid = 1'b1;
    assign read_if.value = ts_delta;

endmodule : state_timer_core
