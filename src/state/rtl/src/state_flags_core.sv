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
module state_flags_core #(
    parameter type ID_T = logic[7:0],
    parameter type FLAGS_T = logic[7:0],
    // Simulation-only
    parameter bit  CACHE_EN  = 1'b1, // Implement 'lookback' cache to enable accurate stats accumulation for
                                     // scenarios where multiple transactions to the same ID are in the update pipeline
    parameter bit  SIM__FAST_INIT = 1'b1 // Optimize sim time by performing gast memory init
)(
    // Clock/reset
    input  logic             clk,
    input  logic             srst,

    output logic             init_done,

    // Control interface
    db_ctrl_intf.peripheral  ctrl_if,

    // Update interface
    state_update_intf.target update_if
);
    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int ID_WID = $bits(ID_T);
    localparam int NUM_FLAGS = $bits(FLAGS_T);
    localparam int DEPTH = 2**ID_WID;
    localparam int MEM_RD_LATENCY = mem_pkg::get_default_rd_latency(DEPTH, $bits(FLAGS_T));
    localparam int MEM_WR_LATENCY = mem_pkg::get_default_wr_latency(DEPTH, $bits(FLAGS_T));
    localparam int MEM_UPDATE_LATENCY = MEM_RD_LATENCY + MEM_WR_LATENCY;

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        logic   valid;
        logic   ctrl;
        ID_T    id;
        logic   init;
        logic   update;
        FLAGS_T flags;
    } rmw_ctxt_t;

    typedef struct packed {
        ID_T    id;
        logic   init;
        FLAGS_T flags;
    } rmw_adj_ctxt_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic   req;
    ID_T    id;

    rmw_ctxt_t rmw_ctxt_in;
    rmw_ctxt_t rmw_ctxt_p [MEM_UPDATE_LATENCY];
    rmw_ctxt_t rmw_ctxt_out;

    logic   ctrl_req;
    logic   ctrl_wr;
    logic   ctrl_sel;
    ID_T    ctrl_id;
    FLAGS_T ctrl_flags;

    FLAGS_T wr_data;
    FLAGS_T wr_flags;
    logic   wr_ack;

    FLAGS_T rd_data;
    FLAGS_T rd_flags;
    logic   rd_ack;

    rmw_adj_ctxt_t rmw_adj_ctxt;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    mem_intf #(.ADDR_WID(ID_WID), .DATA_WID(NUM_FLAGS)) mem_wr_if (.clk(clk));
    mem_intf #(.ADDR_WID(ID_WID), .DATA_WID(NUM_FLAGS)) mem_rd_if (.clk(clk));

    db_intf #(.KEY_T(ID_T), .VALUE_T(FLAGS_T)) ctrl_wr_if (.clk(clk));
    db_intf #(.KEY_T(ID_T), .VALUE_T(FLAGS_T)) ctrl_rd_if (.clk(clk));

    // ----------------------------------
    // Flags memory
    // ----------------------------------
    mem_ram_sdp_sync   #(
        .ADDR_WID       ( ID_WID ),
        .DATA_WID       ( NUM_FLAGS ),
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
    assign mem_rd_if.rst  = 1'b0;
    assign mem_rd_if.en   = 1'b1;
    assign mem_rd_if.req  = req;
    assign mem_rd_if.addr = id;
    assign rd_data = mem_rd_if.data;

    // Memory write interface
    assign mem_wr_if.rst  = init;
    assign mem_wr_if.en   = rmw_ctxt_out.update;
    assign mem_wr_if.req  = mem_rd_if.ack;
    assign mem_wr_if.addr = rmw_ctxt_out.id;
    assign mem_wr_if.data = wr_data;

    // -----------------------------
    // Control transaction handling
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

    assign ctrl_sel = update_if.req ? 1'b0 : 1'b1;

    assign ctrl_req = ctrl_wr_if.req || ctrl_rd_if.req;
    assign ctrl_wr = ctrl_wr_if.req;
    assign ctrl_id = ctrl_wr_if.req ? ctrl_wr_if.key : ctrl_rd_if.key;
    assign ctrl_init = ctrl_wr_if.req && (!ctrl_rd_if.req || !ctrl_wr_if.valid);
    assign ctrl_flags = ctrl_wr_if.valid ? ctrl_wr_if.value : '0;

    assign ctrl_wr_if.rdy = mem_rd_if.rdy && ctrl_sel;
    assign ctrl_wr_if.ack = rmw_ctxt_out.ctrl && wr_ack;
    assign ctrl_wr_if.error = wr_error;
    assign ctrl_wr_if.ack_id = '0;

    assign ctrl_rd_if.rdy = mem_rd_if.rdy && ctrl_sel;
    assign ctrl_rd_if.ack = rmw_ctxt_out.ctrl && rd_ack;
    assign ctrl_rd_if.error = rd_error;
    assign ctrl_rd_if.ack_id = '0;
    assign ctrl_rd_if.valid = 1'b1;
    assign ctrl_rd_if.value = rd_flags;

    // -----------------------------
    // Update interface
    // -----------------------------
    assign update_if.rdy = mem_rd_if.rdy;
    assign update_if.ack = !rmw_ctxt_out.ctrl && rd_ack;
    assign update_if.ack_id = rmw_ctxt_out.id;
    assign update_if.data = rd_flags;

    // -----------------------------
    // Transaction mux
    // - mux between fast path (data plane) and 
    //   slow path (control plane)
    // - strict priority to data plane
    // -----------------------------
    assign req = ctrl_sel ? ctrl_req : update_if.req;
    assign id  = ctrl_sel ? ctrl_id  : update_if.id;

    assign rmw_ctxt_in.valid  = ctrl_sel ? ctrl_req   : update_if.req;
    assign rmw_ctxt_in.ctrl   = ctrl_sel ? 1'b1       : 1'b0;
    assign rmw_ctxt_in.id     = id;
    assign rmw_ctxt_in.init   = ctrl_sel ? ctrl_init  : update_if.init;
    assign rmw_ctxt_in.update = ctrl_sel ? ctrl_wr    : 1'b1;
    assign rmw_ctxt_in.flags  = ctrl_sel ? ctrl_flags : update_if.update;

    // -----------------------------
    // RMW context pipeline
    // -----------------------------
    always_ff @(posedge clk) begin
        for (int i = 1; i < MEM_UPDATE_LATENCY; i++) begin
            rmw_ctxt_p[i] <= rmw_ctxt_p[i-1];
        end
        rmw_ctxt_p[0] <= rmw_ctxt_in;
    end
    assign rmw_ctxt_out = rmw_ctxt_p[MEM_RD_LATENCY-1];

    // Update flags
    always_comb begin
        rd_flags = rd_data;

        // If enabled, adjust read flags according to preceding transactions in the
        // update pipeline that target the same ID
        if (CACHE_EN) begin
            if (rmw_adj_ctxt.init) rd_flags  = rmw_adj_ctxt.flags;
            else                   rd_flags |= rmw_adj_ctxt.flags;
        end
    end

    // Build write transaction
    always_comb begin
        wr_flags = rd_flags;
        if (rmw_ctxt_out.valid && rmw_ctxt_out.update) begin
            if (rmw_ctxt_out.init) wr_flags  = rmw_ctxt_out.flags;
            else                   wr_flags |= rmw_ctxt_out.flags;
        end
    end

    assign wr_data = wr_flags;

    // Ack
    assign rd_ack = rmw_ctxt_out.valid;
    assign rd_error = (rmw_ctxt_out.valid && !rmw_ctxt_out.update && !mem_rd_if.ack);

    assign wr_ack = rmw_ctxt_out.valid && rmw_ctxt_out.update;
    assign wr_error = (rmw_ctxt_out.valid && rmw_ctxt_out.update && !mem_rd_if.ack);

    // RMW cache
    generate
        if (CACHE_EN) begin : g__cache
            rmw_adj_ctxt_t rmw_adj_ctxt_p     [MEM_RD_LATENCY];
            rmw_adj_ctxt_t rmw_adj_ctxt_p_nxt [MEM_RD_LATENCY];
            rmw_ctxt_t     rmw_ctxt_expiring;

            // RMW context for which write is being executed on present cycle
            assign rmw_ctxt_expiring = rmw_ctxt_p[MEM_UPDATE_LATENCY-1];

            // RMW adjustment due to transactions in flight
            // -- at each cycle, adjust (if necessary) each transaction in update pipeline
            //    by considering 'expiring' or oldest transaction in pipeline
            always_comb begin
                // Advance pipeline
                for (int i = 1; i < MEM_RD_LATENCY; i++) begin
                    rmw_adj_ctxt_p_nxt[i] = rmw_adj_ctxt_p[i-1];
                end
                rmw_adj_ctxt_p_nxt[0].id = rmw_ctxt_in.id;
                rmw_adj_ctxt_p_nxt[0].init = 1'b0;
                rmw_adj_ctxt_p_nxt[0].flags = '0;

                // Check each transaction for ID match to expiring transaction; for matches,
                // calculate stats adjustment required
                for (int i = 0; i < MEM_RD_LATENCY; i++) begin
                    if (rmw_ctxt_expiring.id == rmw_adj_ctxt_p_nxt[i].id) begin
                        if (rmw_ctxt_expiring.init) begin
                            rmw_adj_ctxt_p_nxt[i].init = 1'b1;
                            if (rmw_ctxt_expiring.update) rmw_adj_ctxt_p_nxt[i].flags = rmw_ctxt_expiring.flags;
                            else                          rmw_adj_ctxt_p_nxt[i].flags = '0;
                        end else if (rmw_ctxt_expiring.update) begin
                            rmw_adj_ctxt_p_nxt[i].flags |= rmw_ctxt_expiring.flags;
                        end
                    end
                end

                // Also adjust for write latency
                for (int i = MEM_UPDATE_LATENCY-2; i >= MEM_RD_LATENCY-1; i--) begin
                    if (rmw_ctxt_p[i].id == rmw_adj_ctxt_p_nxt[MEM_RD_LATENCY-1].id) begin
                        if (rmw_ctxt_p[i].init) begin
                            rmw_adj_ctxt_p_nxt[MEM_RD_LATENCY-1].init = 1'b1;
                            if (rmw_ctxt_p[i].update) rmw_adj_ctxt_p_nxt[MEM_RD_LATENCY-1].flags = rmw_ctxt_p[i].flags;
                            else                      rmw_adj_ctxt_p_nxt[MEM_RD_LATENCY-1].flags = '0;
                        end else if (rmw_ctxt_p[i].update) begin
                            rmw_adj_ctxt_p_nxt[MEM_RD_LATENCY-1].flags |= rmw_ctxt_p[i].flags;
                        end
                    end
                end
            end

            // Latch RMW adjustments
            always_ff @(posedge clk) begin
                for (int i = 0; i < MEM_RD_LATENCY; i++) begin
                    rmw_adj_ctxt_p[i] <= rmw_adj_ctxt_p_nxt[i];
                end
            end

            assign rmw_adj_ctxt = rmw_adj_ctxt_p[MEM_RD_LATENCY-1];
        end : g__cache
        else begin : g__no_cache
            assign rmw_adj_ctxt.id = '0;
            assign rmw_adj_ctxt.init = 1'b0;
            assign rmw_adj_ctxt.flags = '0;
        end : g__no_cache
    endgenerate

endmodule : state_flags_core
