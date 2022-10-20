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
module htable_cuckoo_controller 
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[15:0],
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 4096},
    parameter int  HASH_LATENCY = 0
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    input  logic              en,

    input  logic              init_done,

    // Hashing interface
    output KEY_T              key  [NUM_TABLES],
    input  hash_t             hash [NUM_TABLES],

    // Control interface
    db_ctrl_intf.peripheral   ctrl_if,                 // KEY_T/VALUE_T configuration

    // Bubble stash interface (size 1)
    db_ctrl_intf.controller   stash_ctrl_if,           // KEY_T/VALUE_T configuration

    // Table control
    db_ctrl_intf.controller   tbl_ctrl_if [NUM_TABLES] // This control interface provides direct access
                                                       // to the underlying hash table for table management
                                                       // (e.g. insertion/deletion/optimization)
                                                       // and therefore the interface configuration is:
                                                       // KEY_T' := hash_t, VALUE_T' := {KEY_T, VALUE_T}
);

    // ----------------------------------
    // Imports
    // ----------------------------------
    import db_pkg::*;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam type TBL_ENTRY_T = struct packed {KEY_T key; VALUE_T value;};

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef enum logic [4:0] {
        RESET               = 0,
        IDLE                = 1,
        CLEAR               = 2,
        CLEAR_PENDING       = 3,
        CLEAR_NEXT          = 4,
        CLEAR_STASH         = 5,
        CLEAR_STASH_PENDING = 6,
        CHECK               = 7,
        CHECK_PENDING       = 8,
        CHECK_NEXT          = 9,
        CHECK_FOUND         = 10,
        CHECK_NOT_FOUND     = 11,
        DELETE              = 12,
        DELETE_PENDING      = 13,
        INSERT_GET          = 14,
        INSERT_GET_PENDING  = 15,
        INSERT_PUSH         = 16,
        INSERT_PUSH_PENDING = 17,
        INSERT_SET          = 18,
        INSERT_SET_PENDING  = 19,
        INSERT_POP          = 20,
        INSERT_POP_PENDING  = 21,
        INSERT_NEXT         = 22,
        DONE                = 23,
        ERROR               = 24
    } state_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    state_t state;
    state_t nxt_state;

    TBL_ENTRY_T __ctrl_if_set_entry;
    TBL_ENTRY_T __ctrl_if_get_entry;

    command_t __command;
    KEY_T     __key;
    VALUE_T   __value;

    logic       prev_valid;
    TBL_ENTRY_T prev_entry;
    KEY_T       prev_key;
    VALUE_T     prev_value;

    logic     stash_active;

    int   tbl_idx;
    logic tbl_idx_reset;
    logic tbl_idx_inc;

    // Control (upstream)
    logic     ctrl_rdy;
    logic     ctrl_ack;
    status_t  ctrl_status;

    // Table control (downstream)
    logic     tbl_req;
    command_t tbl_command;

    // Stash control (downstream)
    logic     stash_req;
    command_t stash_command;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(TBL_ENTRY_T)) __ctrl_if (.clk(clk));
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(TBL_ENTRY_T)) __tbl_ctrl_if [NUM_TABLES] (.clk(clk));

    // ----------------------------------
    // Logic
    // ----------------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (srst) state <= RESET;
        else      state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        ctrl_rdy = 1'b0;
        ctrl_ack = 1'b0;
        ctrl_status = STATUS_ERROR;
        tbl_req = 1'b0;
        tbl_command = COMMAND_NOP;
        stash_req = 1'b0;
        stash_command = COMMAND_NOP;
        tbl_idx_reset = 1'b0;
        tbl_idx_inc = 1'b0;
        case (state)
            RESET : begin
                if (init_done) nxt_state = IDLE;
            end
            IDLE : begin
                tbl_idx_reset = 1'b1;
                ctrl_rdy = 1'b1;
                if (ctrl_if.req) begin
                    case (ctrl_if.command)
                        COMMAND_CLEAR : begin
                            nxt_state = CLEAR;
                        end
                        COMMAND_GET : begin
                            nxt_state = CHECK;
                        end
                        COMMAND_SET : begin
                            nxt_state = CHECK;
                        end
                        COMMAND_UNSET : begin
                            nxt_state = CHECK;
                        end
                        COMMAND_REPLACE : begin
                            nxt_state = CHECK;
                        end
                        COMMAND_NOP : begin
                            nxt_state = DONE;
                        end
                        default : begin
                            nxt_state = ERROR;
                        end
                    endcase
                end
            end
            CLEAR : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_CLEAR;
                if (__ctrl_if.rdy) nxt_state = CLEAR_PENDING;
            end
            CLEAR_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else                               nxt_state = CLEAR_NEXT;
                end
            end
            CLEAR_NEXT : begin
                tbl_idx_inc = 1'b1;
                if (tbl_idx == NUM_TABLES-1) nxt_state = CLEAR_STASH;
                else                         nxt_state = CLEAR;
            end
            CLEAR_STASH : begin
                stash_req = 1'b1;
                stash_command = COMMAND_CLEAR;
                if (stash_ctrl_if.rdy) nxt_state = CLEAR_STASH_PENDING;
            end
            CLEAR_STASH_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else                                   nxt_state = DONE;
                end
            end
            CHECK : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_GET;
                if (__ctrl_if.rdy) nxt_state = CHECK_PENDING;
            end
            CHECK_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK)                            nxt_state = ERROR;
                    else if (__ctrl_if.get_valid && (__ctrl_if.get_key == __key)) nxt_state = CHECK_FOUND;
                    else                                                          nxt_state = CHECK_NEXT;
                end

            end
            CHECK_NEXT : begin
                tbl_idx_inc = 1'b1;
                if (tbl_idx == NUM_TABLES-1) nxt_state = CHECK_NOT_FOUND;
                else                         nxt_state = CHECK;
            end
            CHECK_FOUND : begin
                if      (__command == COMMAND_GET)     nxt_state = DONE;
                else if (__command == COMMAND_UNSET)   nxt_state = DELETE;
                else if (__command == COMMAND_REPLACE) nxt_state = INSERT_SET;
                else                                   nxt_state = ERROR;
            end
            CHECK_NOT_FOUND : begin
                if      (__command == COMMAND_GET) nxt_state = DONE;
                else if (__command == COMMAND_SET) nxt_state = INSERT_GET;
                else                               nxt_state = ERROR;
            end
            DELETE : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_UNSET;
                if (__ctrl_if.rdy) nxt_state = DELETE_PENDING;
            end
            DELETE_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK)                                     nxt_state = ERROR;
                    else if (__ctrl_if.get_valid && (__ctrl_if_get_entry.key == prev_key)) nxt_state = DONE;
                    else                                                                   nxt_state = ERROR;
                end
            end
            INSERT_GET : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_GET;
                if (__ctrl_if.rdy) nxt_state = INSERT_GET_PENDING;
            end
            INSERT_GET_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else if (__ctrl_if.get_valid)      nxt_state = INSERT_PUSH;
                    else                               nxt_state = INSERT_SET;
                end
            end
            INSERT_PUSH : begin
                stash_req = 1'b1;
                stash_command = COMMAND_SET;
                if (stash_ctrl_if.rdy) nxt_state = INSERT_PUSH_PENDING;
            end
            INSERT_PUSH_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else                                   nxt_state = INSERT_SET;
                end
            end
            INSERT_SET : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_SET;
                if (__ctrl_if.rdy) nxt_state = INSERT_SET_PENDING;
            end
            INSERT_SET_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else if (stash_active)             nxt_state = INSERT_POP;
                    else                               nxt_state = DONE;
                end
            end
            INSERT_POP : begin
                stash_req = 1'b1;
                stash_command = COMMAND_UNSET;
                if (stash_ctrl_if.rdy) nxt_state = INSERT_POP_PENDING;
            end
            INSERT_POP_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = ERROR;
                    else                                   nxt_state = INSERT_NEXT;
                end
            end
            INSERT_NEXT : begin
                tbl_idx_inc = 1'b1;
                if (prev_valid) nxt_state = INSERT_GET;
                else            nxt_state = DONE;
            end
            DONE : begin
                ctrl_ack = 1'b1;
                ctrl_status = STATUS_OK;
                nxt_state = IDLE;
            end
            ERROR : begin
                ctrl_ack = 1'b1;
                ctrl_status = STATUS_ERROR;
                nxt_state = IDLE;
            end
        endcase
    end

    // Latch request context
    always_ff @(posedge clk) begin
        if (ctrl_if.req && ctrl_if.rdy) begin
            __key   <= ctrl_if.key;
            __value <= ctrl_if.set_value;
        end else if (state == INSERT_NEXT) begin
            __key   <= prev_key;
            __value <= prev_value;
        end
    end

    always_ff @(posedge clk) begin
        if (ctrl_if.req && ctrl_if.rdy) __command <= ctrl_if.command;
    end

    // Maintain update context
    always_ff @(posedge clk) begin
        if (__ctrl_if.ack) begin
            prev_valid <= __ctrl_if.get_valid;
            prev_entry <= __ctrl_if.get_value;
        end
    end
    assign prev_key = prev_entry.key;
    assign prev_value = prev_entry.value;

    // Maintain stash context
    initial stash_active = 1'b0;
    always @(posedge clk) begin
        if (srst) stash_active <= 1'b0;
        else if (state == INSERT_PUSH) stash_active <= 1'b1;
        else if (state == INSERT_POP)  stash_active <= 1'b0;
    end

    // Drive upstream control interface
    assign ctrl_if.rdy = ctrl_rdy;
    assign ctrl_if.ack = ctrl_ack;
    assign ctrl_if.status = ctrl_status;
    assign ctrl_if.get_valid = prev_valid;
    assign ctrl_if.get_value = prev_value;
    assign ctrl_if.get_key   = prev_key;

    // Drive downstream table interface
    assign __ctrl_if.req       = tbl_req;
    assign __ctrl_if.command   = tbl_command;
    assign __ctrl_if.key       = __key;
    assign __ctrl_if_set_entry.key   = __key;
    assign __ctrl_if_set_entry.value = __value;
    assign __ctrl_if.set_value = __ctrl_if_set_entry;
    assign __ctrl_if_get_entry = __ctrl_if.get_value;

    // Drive bubble stash interface
    assign stash_ctrl_if.req       = stash_req;
    assign stash_ctrl_if.command   = stash_command;
    assign stash_ctrl_if.key       = prev_key;
    assign stash_ctrl_if.set_value = prev_value;
    
    // ----------------------------------
    // Table index control
    // ----------------------------------
    initial tbl_idx = 0;
    always @(posedge clk) begin
        if      (tbl_idx_reset) tbl_idx <= 0;
        else if (tbl_idx_inc)   tbl_idx <= (tbl_idx == NUM_TABLES-1) ? 0 : tbl_idx + 1;
    end

    // ----------------------------------
    // Table control demux
    // ----------------------------------
    db_ctrl_intf_demux #(
        .NUM_IFS ( NUM_TABLES ),
        .KEY_T   ( KEY_T ),
        .VALUE_T ( TBL_ENTRY_T )
    ) i_db_ctrl_intf_demux       (
        .demux_sel               ( tbl_idx ),
        .ctrl_if_from_controller ( __ctrl_if ),
        .ctrl_if_to_peripheral   ( __tbl_ctrl_if )
    );

    // ----------------------------------
    // Adapt to hash interface
    // ----------------------------------
    generate
        for (genvar g_tbl = 0; g_tbl < NUM_TABLES; g_tbl++) begin : g__tbl
            // (Local) signals
            TBL_ENTRY_T set_entry;
            TBL_ENTRY_T get_entry;

            // Map to/from htable entry format
            assign set_entry.key = __tbl_ctrl_if[g_tbl].key;
            assign set_entry.value = __tbl_ctrl_if[g_tbl].set_value;
            assign get_entry = tbl_ctrl_if[g_tbl].get_value;

            // Drive hash interface
            assign key[g_tbl] = __tbl_ctrl_if[g_tbl].key;
            assign tbl_ctrl_if[g_tbl].key = hash[g_tbl];

            // Account for hash latency
            if (HASH_LATENCY > 0) begin : g__hash_latency
                // (Local) typedefs
                typedef struct packed {
                    logic       req;
                    command_t   command;
                    TBL_ENTRY_T entry;
                } req_ctxt_t;

                req_ctxt_t req_ctxt_in;
                req_ctxt_t req_ctxt_out;

                assign req_ctxt_in.req     = __tbl_ctrl_if[g_tbl].req;
                assign req_ctxt_in.command = __tbl_ctrl_if[g_tbl].command;
                assign req_ctxt_in.entry   = set_entry;

                util_delay   #(
                    .DATA_T   ( req_ctxt_t ),
                    .DELAY    ( HASH_LATENCY )
                ) i_util_delay__req_ctxt (
                    .clk      ( clk ),
                    .srst     ( srst ),
                    .data_in  ( req_ctxt_in ),
                    .data_out ( req_ctxt_out )
                );

                assign tbl_ctrl_if[g_tbl].req       = req_ctxt_out.req;
                assign tbl_ctrl_if[g_tbl].command   = req_ctxt_out.command;
                assign tbl_ctrl_if[g_tbl].set_value = req_ctxt_out.entry; 
            end : g__hash_latency
            else begin : g__hash_no_latency
                assign tbl_ctrl_if[g_tbl].req       = __tbl_ctrl_if[g_tbl].req;
                assign tbl_ctrl_if[g_tbl].command   = __tbl_ctrl_if[g_tbl].command;
                assign tbl_ctrl_if[g_tbl].set_value = set_entry;
            end : g__hash_no_latency

            // Drive table control interface
            assign __tbl_ctrl_if[g_tbl].rdy       = tbl_ctrl_if[g_tbl].rdy;
            assign __tbl_ctrl_if[g_tbl].ack       = tbl_ctrl_if[g_tbl].ack;
            assign __tbl_ctrl_if[g_tbl].status    = tbl_ctrl_if[g_tbl].status;
            assign __tbl_ctrl_if[g_tbl].get_valid = tbl_ctrl_if[g_tbl].get_valid;
            assign __tbl_ctrl_if[g_tbl].get_value = get_entry;
            assign __tbl_ctrl_if[g_tbl].get_key   = get_entry.key;
        end : g__tbl
    endgenerate

endmodule : htable_cuckoo_controller

