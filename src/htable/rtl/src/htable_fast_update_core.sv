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
module htable_fast_update_core #(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter int  UPDATE_BURST_SIZE = 8

)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    input  logic              en,

    output logic              init_done,

    // Lookup/update interfaces (from application)
    db_intf.responder         lookup_if,
    db_intf.responder         update_if, // Supports both insertion/deletions
                                         // (indicated by setting valid to 1/0 respectively)

    // Table interfaces
    input   logic             tbl_init_done,
    db_ctrl_intf.controller   tbl_ctrl_if,

    db_intf.requester         tbl_lookup_if

);

    // ----------------------------------
    // Imports
    // ----------------------------------
    import db_pkg::*;
    import htable_pkg::*;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam type UPDATE_ENTRY_T = struct packed {logic ins_del_n; VALUE_T value;};

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef enum logic [3:0] {
        RESET              = 0,
        IDLE               = 1,
        GET_NEXT           = 2,
        GET_NEXT_PENDING   = 3,
        GET_NEXT_DONE      = 4,
        TBL_INSERT         = 5,
        TBL_DELETE         = 6,
        TBL_UPDATE_PENDING = 7,
        STASH_POP          = 8,
        STASH_POP_PENDING  = 9,
        DONE               = 10,
        ERROR              = 11
    } state_t;

    typedef struct packed {
        logic          valid;
        logic          error;
        UPDATE_ENTRY_T entry;
    } stash_resp_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    state_t state;
    state_t nxt_state;

    logic          stash_init_done;
    UPDATE_ENTRY_T update_entry;

    stash_resp_t stash_resp_in;
    stash_resp_t stash_resp_out;

    KEY_T   ctrl_key;
    VALUE_T ctrl_value;

    // Stash control
    logic     stash_req;
    command_t stash_command;

    UPDATE_ENTRY_T stash_ctrl_if_get_entry;

    // Table control
    logic     tbl_req;
    command_t tbl_command;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf stash_info_if__unused ();
    db_status_intf stash_status_if (.clk(clk), .srst(srst));
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(UPDATE_ENTRY_T)) stash_ctrl_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(UPDATE_ENTRY_T)) stash_lookup_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(UPDATE_ENTRY_T)) stash_update_if (.clk(clk));

    // ----------------------------------
    // Init done
    // ----------------------------------
    assign init_done = tbl_init_done && stash_init_done;

    // ----------------------------------
    // Update stash
    // ----------------------------------
    db_stash_fifo #(
        .KEY_T     ( KEY_T ),
        .VALUE_T   ( UPDATE_ENTRY_T ),
        .SIZE      ( UPDATE_BURST_SIZE )
    ) i_db_stash   (
        .clk       ( clk ),
        .srst      ( srst ),
        .init_done ( stash_init_done ),
        .info_if   ( stash_info_if__unused ),
        .ctrl_if   ( stash_ctrl_if ),
        .status_if ( stash_status_if ),
        .app_wr_if ( stash_update_if ),
        .app_rd_if ( stash_lookup_if )
    );

    // Map from common lookup/update interfaces to stash-specific interfaces
    assign stash_lookup_if.req = lookup_if.req && tbl_lookup_if.rdy;
    assign stash_lookup_if.key = lookup_if.key;
    assign stash_lookup_if.next = 1'b0;

    assign stash_update_if.req = update_if.req && (stash_status_if.fill < UPDATE_BURST_SIZE);
    assign stash_update_if.key = update_if.key;
    assign stash_update_if.next = 1'b0;
    assign stash_update_if.valid = 1'b1;
    assign update_entry.ins_del_n = update_if.valid;
    assign update_entry.value = update_if.value;
    assign stash_update_if.value = update_entry;

    assign update_if.rdy = stash_update_if.rdy && (stash_status_if.fill < UPDATE_BURST_SIZE);
    assign update_if.ack = stash_update_if.ack;
    assign update_if.error = stash_update_if.error;
    assign update_if.next_key = '0;

    // Store lookup context
    assign stash_resp_in.error = stash_lookup_if.error;
    assign stash_resp_in.valid = stash_lookup_if.valid;
    assign stash_resp_in.entry = stash_lookup_if.value;

    fifo_small  #(
        .DATA_T  ( stash_resp_t ),
        .DEPTH   ( NUM_RD_TRANSACTIONS )
    ) i_fifo_small__stash_resp_ctxt (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr      ( stash_lookup_if.ack ),
        .wr_data ( stash_resp_in ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( tbl_lookup_if.ack ),
        .rd_data ( stash_resp_out ),
        .empty   ( ),
        .uflow   ( )
    );

    // ----------------------------------
    // Drive table lookup interface
    // ----------------------------------
    assign tbl_lookup_if.req = lookup_if.req && stash_lookup_if.rdy;
    assign tbl_lookup_if.key = lookup_if.key;
    assign tbl_lookup_if.next = 1'b0;

    // ----------------------------------
    // Drive lookup response
    // ----------------------------------
    assign lookup_if.rdy = tbl_lookup_if.rdy && stash_lookup_if.rdy;
    assign lookup_if.ack = tbl_lookup_if.ack;

    always_comb begin
        lookup_if.valid = 1'b0;
        lookup_if.value = '0;
        if (stash_resp_out.valid) begin
            if (stash_resp_out.entry.ins_del_n) begin
                lookup_if.valid = 1'b1;
                lookup_if.value = stash_resp_out.entry.value;
            end else begin
                lookup_if.valid = 1'b0;
            end
        end else begin
            lookup_if.valid = tbl_lookup_if.valid;
            lookup_if.value = tbl_lookup_if.value;
        end
    end
    assign lookup_if.error = tbl_lookup_if.error || stash_resp_out.error;
    assign lookup_if.next_key = '0;

    // ----------------------------------
    // Update stash controller
    // ----------------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        stash_req = 1'b0;
        stash_command = COMMAND_NOP;
        tbl_req = 1'b0;
        tbl_command = COMMAND_NOP;
        case (state)
            RESET : begin
                if (init_done) nxt_state = IDLE;
            end
            IDLE : begin
                if (en) begin
                    if (stash_status_if.fill > 0) nxt_state = GET_NEXT;
                end
            end
            GET_NEXT : begin
                stash_req = 1'b1;
                stash_command = COMMAND_GET_NEXT;
                if (stash_ctrl_if.rdy) nxt_state = GET_NEXT_PENDING;
            end
            GET_NEXT_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK)     nxt_state = ERROR;
                    else if (stash_ctrl_if.get_valid) begin
                        if (stash_ctrl_if_get_entry.ins_del_n) nxt_state = TBL_INSERT;
                        else                                   nxt_state = TBL_DELETE;
                    end else                                   nxt_state = IDLE;
                end
            end
            TBL_INSERT : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_SET;
                if (tbl_ctrl_if.rdy) nxt_state = TBL_UPDATE_PENDING;
            end
            TBL_DELETE : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_UNSET;
                if (tbl_ctrl_if.rdy) nxt_state = TBL_UPDATE_PENDING;
            end
            TBL_UPDATE_PENDING : begin
                if (tbl_ctrl_if.ack) begin
                    if (tbl_ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else                                 nxt_state = STASH_POP;
                end
            end
            STASH_POP : begin
                stash_req = 1'b1;
                stash_command = COMMAND_UNSET_NEXT;
                if (stash_ctrl_if.rdy) nxt_state = STASH_POP_PENDING;
            end
            STASH_POP_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else if (stash_ctrl_if.get_valid)      nxt_state = DONE;
                    else                                   nxt_state = ERROR;
                end
            end
            DONE : begin
                nxt_state = IDLE;
            end
            ERROR : begin
                nxt_state = IDLE;
            end
            default : begin
                nxt_state = IDLE;
            end
        endcase
    end

    // Latch update data
    always_ff @(posedge clk) begin
        if (stash_ctrl_if.ack) begin
            ctrl_key   <= stash_ctrl_if.get_key;
            ctrl_value <= stash_ctrl_if_get_entry.value;
        end
    end

    // ----------------------------------
    // Drive stash control interface
    // ----------------------------------
    assign stash_ctrl_if.req = stash_req;
    assign stash_ctrl_if.command = stash_command;
    assign stash_ctrl_if.key = ctrl_key;
    assign stash_ctrl_if.set_value = '0;
    assign stash_ctrl_if_get_entry = stash_ctrl_if.get_value;

    // ----------------------------------
    // Drive table control interface
    // ----------------------------------
    assign tbl_ctrl_if.req = tbl_req;
    assign tbl_ctrl_if.command = tbl_command;
    assign tbl_ctrl_if.key = ctrl_key;
    assign tbl_ctrl_if.set_value = ctrl_value;

endmodule : htable_fast_update_core
