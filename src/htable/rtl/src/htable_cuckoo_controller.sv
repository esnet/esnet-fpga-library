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

    // AXI-L control/monitoring
    axi4l_intf.peripheral     axil_if,

    // Hashing interface
    output KEY_T              key  [NUM_TABLES],
    input  hash_t             hash [NUM_TABLES],

    // Table control
    db_ctrl_intf.peripheral   ctrl_if,                 // KEY_T/VALUE_T configuration

    // Status reporting
    db_status_intf.peripheral status_if,

    // Bubble stash interface (size 1)
    db_ctrl_intf.controller   stash_ctrl_if,           // KEY_T/VALUE_T configuration

    // (Sub)table control
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

    localparam int TBL_IDX_WID = $clog2(NUM_TABLES);

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef enum logic [4:0] {
        RESET                    = 0,
        IDLE                     = 1,
        CLEAR                    = 2,
        CLEAR_PENDING            = 3,
        CLEAR_NEXT               = 4,
        CLEAR_STASH              = 5,
        CLEAR_STASH_PENDING      = 6,
        CHECK                    = 7,
        CHECK_PENDING            = 8,
        CHECK_NEXT               = 9,
        CHECK_FOUND              = 10,
        CHECK_NOT_FOUND          = 11,
        DELETE                   = 12,
        DELETE_PENDING           = 13,
        INSERT_PUSH_NEXT         = 14,
        INSERT_PUSH_NEXT_PENDING = 15,
        INSERT_GET_PREV          = 16,
        INSERT_GET_PREV_PENDING  = 17,
        INSERT_PUSH_PREV         = 18,
        INSERT_PUSH_PREV_PENDING = 19,
        INSERT_SET_NEXT          = 20,
        INSERT_SET_NEXT_PENDING  = 21,
        INSERT_POP_NEXT          = 22,
        INSERT_POP_NEXT_PENDING  = 23,
        INSERT_NEXT              = 24,
        DONE                     = 25,
        INSERT_KEY_EXISTS        = 26,
        INSERT_LOOP              = 27,
        DELETE_KEY_NOT_FOUND     = 28,
        TBL_ERROR                = 29,
        STASH_ERROR              = 30,
        ERROR                    = 31
    } state_t;

    typedef logic [TBL_IDX_WID-1:0] tbl_idx_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic __srst;
    logic __en;

    logic [7:0] state_mon;

    state_t state;
    state_t nxt_state;

    TBL_ENTRY_T __ctrl_if_set_entry;
    TBL_ENTRY_T __ctrl_if_get_entry;

    command_t __command;
    KEY_T     __key;
    VALUE_T   __value;

    KEY_T       insert_key;

    logic       prev_valid;
    TBL_ENTRY_T prev_entry;
    KEY_T       prev_key;
    VALUE_T     prev_value;

    logic     stash_active;
    logic     insert_loop_detected;

    tbl_idx_t tbl_idx;
    logic     tbl_idx_reset;
    logic     tbl_idx_inc;

    // Control (upstream)
    logic     ctrl_rdy;
    logic     ctrl_ack;
    logic     ctrl_valid;
    status_t  ctrl_status;

    // Table control (downstream)
    logic     tbl_req;
    command_t tbl_command;

    // Stash control (downstream)
    logic     stash_req;
    command_t stash_command;

    // Error flags
    logic     insert_key_exists;
    logic     insert_loop;
    logic     delete_key_not_found;
    logic     tbl_error;
    logic     stash_error;

    // Debug signals
    logic        cuckoo_ops_reset;
    logic        cuckoo_ops_inc;
    logic [31:0] cuckoo_ops;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(TBL_ENTRY_T)) __ctrl_if (.clk(clk));
    db_ctrl_intf #(.KEY_T(KEY_T), .VALUE_T(TBL_ENTRY_T)) __tbl_ctrl_if [NUM_TABLES] (.clk(clk));

    axi4l_intf #() axil_if__clk ();
    htable_cuckoo_reg_intf reg_if ();

    // ----------------------------------
    // AXI-L control
    // ----------------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    htable_cuckoo_reg_blk i_htable_cuckoo_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    assign reg_if.info_nxt.num_tables = NUM_TABLES[7:0];
    assign reg_if.info_nxt.key_width = $bits(KEY_T);
    assign reg_if.info_nxt.value_width = $bits(VALUE_T);
    assign reg_if.info_nxt_v = 1'b1;

    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset_mon = __srst;
    assign reg_if.status_nxt.enable_mon = __en;
    assign reg_if.status_nxt.ready_mon = init_done;

    assign state_mon = {3'b0, state};
    assign reg_if.dbg_status_nxt_v = 1'b1;
    assign reg_if.dbg_status_nxt.state = htable_cuckoo_reg_pkg::fld_dbg_status_state_t'(state_mon);

    // Block reset
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) __srst <= 1'b1;
        else                              __srst <= 1'b0;
    end

    // Block enable
    initial __en = 1'b0;
    always @(posedge clk) begin
        if (en && reg_if.control.enable) __en <= 1'b1;
        else                             __en <= 1'b0;
    end

    // ----------------------------------
    // Logic
    // ----------------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (__srst) state <= RESET;
        else        state <= nxt_state;
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
        insert_key_exists = 1'b0;
        insert_loop = 1'b0;
        delete_key_not_found = 1'b0;
        tbl_error = 1'b0;
        stash_error = 1'b0;
        cuckoo_ops_reset = 1'b0;
        cuckoo_ops_inc = 1'b0;
        case (state)
            RESET : begin
                if (init_done) nxt_state = IDLE;
            end
            IDLE : begin
                tbl_idx_reset = 1'b1;
                cuckoo_ops_reset = 1'b1;
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
                    if (__ctrl_if.status != STATUS_OK) nxt_state = TBL_ERROR;
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
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = STASH_ERROR;
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
                    if (__ctrl_if.status != STATUS_OK)                                  nxt_state = TBL_ERROR;
                    else if (__ctrl_if.get_valid && (__ctrl_if_get_entry.key == __key)) nxt_state = CHECK_FOUND;
                    else                                                                nxt_state = CHECK_NEXT;
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
                else if (__command == COMMAND_REPLACE) nxt_state = INSERT_SET_NEXT;
                else if (__command == COMMAND_SET)     nxt_state = INSERT_KEY_EXISTS;
                else                                   nxt_state = ERROR;
            end
            CHECK_NOT_FOUND : begin
                if      (__command == COMMAND_GET)   nxt_state = DONE;
                else if (__command == COMMAND_SET)   nxt_state = INSERT_PUSH_NEXT;
                else if (__command == COMMAND_UNSET) nxt_state = DELETE_KEY_NOT_FOUND;
                else                                 nxt_state = ERROR;
            end
            DELETE : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_UNSET;
                if (__ctrl_if.rdy) nxt_state = DELETE_PENDING;
            end
            DELETE_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK)                                  nxt_state = TBL_ERROR;
                    else if (__ctrl_if.get_valid && (__ctrl_if_get_entry.key == __key)) nxt_state = DONE;
                    else                                                                nxt_state = ERROR;
                end
            end
            INSERT_PUSH_NEXT : begin
                stash_req = 1'b1;
                stash_command = COMMAND_SET;
                if (stash_ctrl_if.rdy) nxt_state = INSERT_PUSH_NEXT_PENDING;
            end
            INSERT_PUSH_NEXT_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = STASH_ERROR;
                    else                                   nxt_state = INSERT_GET_PREV;
                end
            end
            INSERT_GET_PREV : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_GET;
                if (__ctrl_if.rdy) nxt_state = INSERT_GET_PREV_PENDING;
            end
            INSERT_GET_PREV_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK) nxt_state = TBL_ERROR;
                    else if (__ctrl_if.get_valid)      nxt_state = INSERT_PUSH_PREV;
                    else                               nxt_state = INSERT_SET_NEXT;
                end
            end
            INSERT_PUSH_PREV : begin
                stash_req = 1'b1;
                stash_command = COMMAND_SET;
                if (stash_ctrl_if.rdy) nxt_state = INSERT_PUSH_PREV_PENDING;
            end
            INSERT_PUSH_PREV_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = STASH_ERROR;
                    else                                   nxt_state = INSERT_SET_NEXT;
                end
            end
            INSERT_SET_NEXT : begin
                tbl_req = 1'b1;
                tbl_command = COMMAND_SET;
                if (__ctrl_if.rdy) nxt_state = INSERT_SET_NEXT_PENDING;
            end
            INSERT_SET_NEXT_PENDING : begin
                if (__ctrl_if.ack) begin
                    if (__ctrl_if.status != STATUS_OK) nxt_state = TBL_ERROR;
                    else                               nxt_state = INSERT_POP_NEXT;
                end
            end
            INSERT_POP_NEXT : begin
                stash_req = 1'b1;
                stash_command = COMMAND_UNSET;
                if (stash_ctrl_if.rdy) nxt_state = INSERT_POP_NEXT_PENDING;
            end
            INSERT_POP_NEXT_PENDING : begin
                if (stash_ctrl_if.ack) begin
                    if (stash_ctrl_if.status != STATUS_OK) nxt_state = STASH_ERROR;
                    else if (insert_loop_detected)         nxt_state = ERROR;
                    else if (stash_active)                 nxt_state = INSERT_NEXT;
                    else                                   nxt_state = DONE;
                end
            end
            INSERT_NEXT : begin
                tbl_idx_inc = 1'b1;
                cuckoo_ops_inc = 1'b1;
                // check for cuckoo operations exceeding configured limit (simplified cycle detection)
                // perform this check when the original inserted key is 'in-hand', so that it ends up
                // being the key that 'fails' to insert
                if ((prev_key == insert_key) && (cuckoo_ops > reg_if.cuckoo_control.ops_limit)) nxt_state = INSERT_LOOP;
                else nxt_state = INSERT_GET_PREV;
            end
            DONE : begin
                ctrl_ack = 1'b1;
                ctrl_status = STATUS_OK;
                nxt_state = IDLE;
            end
            INSERT_KEY_EXISTS : begin
                insert_key_exists = 1'b1;
                nxt_state = ERROR;
            end
            INSERT_LOOP: begin
                insert_loop = 1'b1;
                nxt_state = INSERT_POP_NEXT;
            end
            DELETE_KEY_NOT_FOUND : begin
                delete_key_not_found = 1'b1;
                nxt_state = ERROR;
            end
            TBL_ERROR : begin
                tbl_error = 1'b1;
                nxt_state = ERROR;
            end
            STASH_ERROR : begin
                stash_error = 1'b1;
                nxt_state = ERROR;
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

    // Latch key to check for insertion loops
    always_ff @(posedge clk) begin
        if (ctrl_if.req && ctrl_if.rdy) begin
            insert_key <= ctrl_if.key;
        end
    end

    // Maintain stash context
    initial stash_active = 1'b0;
    always @(posedge clk) begin
        if (__srst) stash_active <= 1'b0;
        else if (state == INSERT_PUSH_PREV) stash_active <= 1'b1;
        else if (state == INSERT_GET_PREV)  stash_active <= 1'b0;
    end

    // Maintain loop detection context
    always_ff @(posedge clk) begin
        if (state == IDLE) insert_loop_detected <= 1'b0;
        else if (state == INSERT_LOOP) insert_loop_detected <= 1'b1;
    end

    // Drive upstream control interface
    initial ctrl_valid = 1'b0;
    always @(posedge clk) begin
        if (__srst) ctrl_valid <= 1'b0;
        else begin
            if (state == IDLE)                 ctrl_valid <= 1'b0;
            else if (state == CHECK_FOUND)     ctrl_valid <= 1'b1;
            else if (state == CHECK_NOT_FOUND) ctrl_valid <= 1'b0;
        end
    end

    assign ctrl_if.rdy = ctrl_rdy;
    assign ctrl_if.ack = ctrl_ack;
    assign ctrl_if.status = ctrl_status;
    assign ctrl_if.get_valid = ctrl_valid;
    assign ctrl_if.get_value = ctrl_valid ? prev_value : '0;
    assign ctrl_if.get_key   = ctrl_valid ? prev_key   : '0;

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
    always_comb begin
        if (state == INSERT_PUSH_NEXT || state == INSERT_POP_NEXT) begin
            stash_ctrl_if.key       = __key;
            stash_ctrl_if.set_value = __value;
        end else begin
            stash_ctrl_if.key       = prev_key;
            stash_ctrl_if.set_value = prev_value;
        end
    end

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
        .clk                     ( clk ),
        .srst                    ( __srst ),
        .demux_sel               ( {{32-TBL_IDX_WID{1'b0}}, tbl_idx} ),
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

            // Map to/from htable entry format
            assign set_entry.key = __tbl_ctrl_if[g_tbl].key;
            assign set_entry.value = __tbl_ctrl_if[g_tbl].set_value;

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
                    .srst     ( 1'b0 ),
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
            assign __tbl_ctrl_if[g_tbl].get_value = tbl_ctrl_if[g_tbl].get_value;
            assign __tbl_ctrl_if[g_tbl].get_key   = '0;
        end : g__tbl
    endgenerate

    // -----------------------------
    // Cuckoo operations count
    // -----------------------------
    always_ff @(posedge clk) begin
        if (cuckoo_ops_reset)    cuckoo_ops <= 0;
        else if (cuckoo_ops_inc) cuckoo_ops <= cuckoo_ops + 1;
    end

    // -----------------------------
    // Counters
    // -----------------------------
    logic __insert_ok;
    logic __insert_fail;
    logic __delete_ok;
    logic __delete_fail;
    logic __active;

    logic cnt_latch;
    logic cnt_clear;

    logic [63:0] cnt_insert_ok;
    logic [63:0] cnt_insert_fail;
    logic [63:0] cnt_delete_ok;
    logic [63:0] cnt_delete_fail;
    logic [31:0] cnt_insert_key_exists;
    logic [31:0] cnt_insert_loop;
    logic [31:0] cnt_delete_key_not_found;
    logic [31:0] cnt_tbl_error;
    logic [31:0] cnt_stash_error;
    logic [31:0] cnt_active;
    logic [31:0] cnt_active_min;
    logic [31:0] cnt_active_max;

    // Synthesize (and buffer) counter update signals
    always_ff @(posedge clk) begin
        __insert_ok   <= 1'b0;
        __insert_fail <= 1'b0;
        __delete_ok   <= 1'b0;
        __delete_fail <= 1'b0;
        if (ctrl_if.ack) begin
            if (ctrl_if.status == STATUS_OK) begin
                if (__command == COMMAND_SET)        __insert_ok <= 1'b1;
                else if (__command == COMMAND_UNSET) __delete_ok <= 1'b1;
            end else begin
                if (__command == COMMAND_SET)        __insert_fail <= 1'b1;
                else if (__command == COMMAND_UNSET) __delete_fail <= 1'b1;
            end
        end
    end

    // Buffer latch/clear signals from regmap
    initial begin
        cnt_clear = 1'b0;
    end
    always @(posedge clk) begin
        if (__srst || (reg_if.cnt_control_wr_evt && reg_if.cnt_control._clear)) cnt_clear <= 1'b1;
        else cnt_clear <= 1'b0;
    end

    always_ff @(posedge clk) begin
        if (reg_if.cnt_control_wr_evt) cnt_latch <= 1'b1;
        else                           cnt_latch <= 1'b0;
    end

    // Insert OK
    always_ff @(posedge clk) begin
        if (cnt_clear)        cnt_insert_ok <= 0;
        else if (__insert_ok) cnt_insert_ok <= cnt_insert_ok + 1;
    end
    // Insert FAIL
    always_ff @(posedge clk) begin
        if (cnt_clear)          cnt_insert_fail <= 0;
        else if (__insert_fail) cnt_insert_fail <= cnt_insert_fail + 1;
    end
    // Insert : key exists
    always_ff @(posedge clk) begin
        if (cnt_clear)              cnt_insert_key_exists <= 0;
        else if (insert_key_exists) cnt_insert_key_exists <= cnt_insert_key_exists + 1;
    end
    // Insert : insertion loop detected
    always_ff @(posedge clk) begin
        if (cnt_clear)        cnt_insert_loop <= 0;
        else if (insert_loop) cnt_insert_loop <= cnt_insert_loop + 1;
    end
    // Delete OK
    always_ff @(posedge clk) begin
        if (cnt_clear)        cnt_delete_ok <= 0;
        else if (__delete_ok) cnt_delete_ok <= cnt_delete_ok + 1;
    end
    // Delete FAIL
    always_ff @(posedge clk) begin
        if (cnt_clear)          cnt_delete_fail <= 0;
        else if (__delete_fail) cnt_delete_fail <= cnt_delete_fail + 1;
    end
    // Delete : key not present
    always_ff @(posedge clk) begin
        if (cnt_clear)                 cnt_delete_key_not_found <= 0;
        else if (delete_key_not_found) cnt_delete_key_not_found <= cnt_delete_key_not_found + 1;
    end
    // Table access error
    always_ff @(posedge clk) begin
        if (cnt_clear)      cnt_tbl_error <= 0;
        else if (tbl_error) cnt_tbl_error <= cnt_tbl_error + 1;
    end
    // Stash access error
    always_ff @(posedge clk) begin
        if (cnt_clear)        cnt_stash_error <= 0;
        else if (stash_error) cnt_stash_error <= cnt_stash_error + 1;
    end
    // Active
    always_ff @(posedge clk) begin
        if (__srst) cnt_active <= 0;
        else if (__insert_ok) cnt_active <= cnt_active + 1;
        else if (__delete_ok) cnt_active <= cnt_active - 1;
    end

    // Active (min)
    always_ff @(posedge clk) begin
        if (cnt_clear) cnt_active_min <= cnt_active;
        else if (cnt_active < cnt_active_min) cnt_active_min <= cnt_active;
    end

    // Active (max)
    always_ff @(posedge clk) begin
        if (cnt_clear) cnt_active_max <= cnt_active;
        else if (cnt_active > cnt_active_max) cnt_active_max <= cnt_active;
    end

    assign reg_if.cnt_insert_ok_upper_nxt_v      = cnt_latch;
    assign reg_if.cnt_insert_ok_lower_nxt_v      = cnt_latch;
    assign reg_if.cnt_insert_fail_upper_nxt_v    = cnt_latch;
    assign reg_if.cnt_insert_fail_lower_nxt_v    = cnt_latch;
    assign reg_if.cnt_insert_key_exists_nxt_v    = cnt_latch;
    assign reg_if.cnt_insert_loop_nxt_v          = cnt_latch;
    assign reg_if.cnt_delete_ok_upper_nxt_v      = cnt_latch;
    assign reg_if.cnt_delete_ok_lower_nxt_v      = cnt_latch;
    assign reg_if.cnt_delete_fail_upper_nxt_v    = cnt_latch;
    assign reg_if.cnt_delete_fail_lower_nxt_v    = cnt_latch;
    assign reg_if.cnt_delete_key_not_found_nxt_v = cnt_latch;
    assign reg_if.cnt_tbl_error_nxt_v            = cnt_latch;
    assign reg_if.cnt_stash_error_nxt_v          = cnt_latch;
    assign reg_if.cnt_active_nxt_v               = cnt_latch;
    assign reg_if.cnt_active_min_nxt_v           = cnt_latch;
    assign reg_if.cnt_active_max_nxt_v           = cnt_latch;

    assign {reg_if.cnt_insert_ok_upper_nxt,   reg_if.cnt_insert_ok_lower_nxt}   = cnt_insert_ok;
    assign {reg_if.cnt_insert_fail_upper_nxt, reg_if.cnt_insert_fail_lower_nxt} = cnt_insert_fail;
    assign {reg_if.cnt_delete_ok_upper_nxt,   reg_if.cnt_delete_ok_lower_nxt}   = cnt_delete_ok;
    assign {reg_if.cnt_delete_fail_upper_nxt, reg_if.cnt_delete_fail_lower_nxt} = cnt_delete_fail;
    assign reg_if.cnt_insert_key_exists_nxt    = cnt_insert_key_exists;
    assign reg_if.cnt_insert_loop_nxt          = cnt_insert_loop;
    assign reg_if.cnt_delete_key_not_found_nxt = cnt_delete_key_not_found;
    assign reg_if.cnt_tbl_error_nxt   = cnt_tbl_error;
    assign reg_if.cnt_stash_error_nxt = cnt_stash_error;
    assign reg_if.cnt_active_nxt      = cnt_active;
    assign reg_if.cnt_active_min_nxt  = cnt_active_min;
    assign reg_if.cnt_active_max_nxt  = cnt_active_max;

    // -----------------------------
    // Debug Counters
    // -----------------------------
    logic        dbg_cnt_clear;
    logic [31:0] dbg_cnt_cuckoo_ops_last;
    logic [31:0] dbg_cnt_cuckoo_ops_max;

    // Buffer clear signals from regmap
    initial begin
        dbg_cnt_clear = 1'b0;
    end
    always @(posedge clk) begin
        if (__srst || (reg_if.dbg_cnt_control_wr_evt && reg_if.dbg_cnt_control._clear)) dbg_cnt_clear <= 1'b1;
        else dbg_cnt_clear <= 1'b0;
    end

    // Cuckoo ops (last)
    always_ff @(posedge clk) begin
        if      (dbg_cnt_clear)                dbg_cnt_cuckoo_ops_last <= 0;
        else if (__insert_ok || __insert_fail) dbg_cnt_cuckoo_ops_last <= cuckoo_ops;
    end
    // Cuckoo ops (max)
    initial dbg_cnt_cuckoo_ops_max = 0;
    always @(posedge clk) begin
        if      (dbg_cnt_clear)                                                           dbg_cnt_cuckoo_ops_max <= 0;
        else if ((__insert_ok || __insert_fail) && (cuckoo_ops > dbg_cnt_cuckoo_ops_max)) dbg_cnt_cuckoo_ops_max <= cuckoo_ops;
    end

    assign reg_if.dbg_cnt_active_nxt_v          = 1'b1;
    assign reg_if.dbg_cnt_cuckoo_ops_last_nxt_v = 1'b1;
    assign reg_if.dbg_cnt_cuckoo_ops_max_nxt_v  = 1'b1;

    assign reg_if.dbg_cnt_active_nxt          = cnt_active;
    assign reg_if.dbg_cnt_cuckoo_ops_last_nxt = dbg_cnt_cuckoo_ops_last;
    assign reg_if.dbg_cnt_cuckoo_ops_max_nxt  = dbg_cnt_cuckoo_ops_max;

    // -----------------------------
    // Assign status interface
    // -----------------------------
    assign status_if.fill = cnt_active;
    assign status_if.empty = (cnt_active == 0);
    assign status_if.full = 0; // Not implemented
    assign status_if.evt_activate = __insert_ok;
    assign status_if.evt_deactivate = __delete_ok;

endmodule : htable_cuckoo_controller

