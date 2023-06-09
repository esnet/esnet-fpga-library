module state_cache_core
    import htable_pkg::*;
#(
    parameter type KEY_T = logic[15:0],
    parameter type ID_T = logic[15:0],
    parameter int  NUM_IDS = 2**$bits(ID_T),
    parameter int  NUM_TABLES = 3,
    parameter int  TABLE_SIZE [NUM_TABLES] = '{default: 4096},
    parameter int  HASH_LATENCY = 0,
    parameter int  NUM_WR_TRANSACTIONS = 2,
    parameter int  NUM_RD_TRANSACTIONS = 8,
    parameter int  UPDATE_BURST_SIZE = 8,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
)(
    // Clock/reset
    input  logic                 clk,
    input  logic                 srst,

    input  logic                 en,

    output logic                 init_done,

    // AXI-L control interface
    axi4l_intf.peripheral        axil_if,

    // Lookup interface (from application) : use KEY to lookup ID; value field is encoded as {new, ID}
    db_intf.responder            lookup_if,

    // Delete interface (from application) : Delete entry corresponding to ID
    db_intf.responder            delete_if,

    // Hashing interface
    output KEY_T                 lookup_key,
    input  hash_t                lookup_hash [NUM_TABLES],

    output KEY_T                 ctrl_key    [NUM_TABLES],
    input  hash_t                ctrl_hash   [NUM_TABLES],

    // Read/write interfaces (to database)
    output logic                 tbl_init      [NUM_TABLES],
    input  logic                 tbl_init_done [NUM_TABLES],
    db_intf.requester            tbl_wr_if     [NUM_TABLES],
    db_intf.requester            tbl_rd_if     [NUM_TABLES]

);

    // ----------------------------------
    // Imports
    // ----------------------------------
    import state_pkg::*;

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int ID_WID = $bits(ID_T);
    localparam int KEY_WID = $bits(KEY_T);
    
    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef struct packed {
        logic _new;
        ID_T  id;
    } lookup_result_t;

    typedef struct packed {
        KEY_T key;
        logic back_to_back;
    } lookup_req_ctxt_t;

    typedef enum logic [2:0] {
        DELETE_RESET          = 0,
        DELETE_IDLE           = 1,
        DELETE_REVMAP_REQ     = 2,
        DELETE_REVMAP_PENDING = 3,
        DELETE_REQ            = 4,
        DELETE_DEALLOC_ID     = 5,
        DELETE_DONE           = 6,
        DELETE_ERROR          = 7
    } delete_state_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic ctrl_reset;
    logic ctrl_en;

    logic __srst;
    logic __en;

    logic htable_ctrl_reset;
    logic htable_ctrl_en;
    logic htable_init;
    logic htable_init_done;
    logic htable_srst;
    logic htable_en;

    logic            last_lookup_key_valid;
    KEY_T            last_lookup_key;
    logic            last_lookup_valid;
    lookup_result_t  last_lookup_result;

    logic back_to_back_lookup_valid;

    lookup_req_ctxt_t lookup_req_ctxt_in;
    lookup_req_ctxt_t lookup_req_ctxt_out;

    logic allocator_init_done;

    logic alloc_req;
    logic alloc_rdy;
    ID_T  alloc_id;

    logic dealloc_req;
    logic dealloc_rdy;
    ID_T  dealloc_id;

    logic err_alloc;
    logic err_dealloc;
    ID_T  err_id;

    logic revmap_init_done;
    logic revmap_rd_req;

    logic insert_req;
    KEY_T insert_key;
    logic insert_rdy;
    logic insert_done;
    logic insert_error;
    ID_T  insert_id;

    logic insert_sel;

    lookup_result_t lookup_result;

    delete_state_t delete_state;
    delete_state_t nxt_delete_state;

    logic [7:0] delete_state_mon_in;
    logic [7:0] delete_state_mon_out;

    logic delete_req;
    KEY_T delete_key;
    logic delete_rdy;
    logic delete_done;
    logic delete_error;
    ID_T  delete_id;

    logic delete_if_rdy;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf htable_info_if ();
    db_status_intf htable_status_if (.clk(clk), .srst(htable_srst));
    db_ctrl_intf  #(.KEY_T(KEY_T), .VALUE_T(ID_T)) htable_ctrl_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(ID_T)) htable_lookup_if (.clk(clk));
    db_intf #(.KEY_T(KEY_T), .VALUE_T(ID_T)) htable_update_if (.clk(clk));

    mem_intf #(.ADDR_WID(ID_WID), .DATA_WID(KEY_WID)) revmap_wr_if (.clk(clk));
    mem_intf #(.ADDR_WID(ID_WID), .DATA_WID(KEY_WID)) revmap_rd_if (.clk(clk));

    axi4l_intf #() cache_axil_if ();
    axi4l_intf #() cache_axil_if__clk ();
    axi4l_intf #() htable_axil_if ();
    axi4l_intf #() db_axil_if ();
    axi4l_intf #() allocator_axil_if ();

    state_cache_reg_intf reg_if ();

    // ----------------------------------
    // Init done
    // ----------------------------------
    always @(posedge clk) begin
        if (srst) init_done <= 1'b0;
        else if (htable_init_done && allocator_init_done && revmap_init_done) init_done <= 1'b1;
        else init_done <= 1'b0;
    end

    // ----------------------------------
    // AXI-L control
    // ----------------------------------
    // Decoder
    state_cache_decoder i_state_cache_decoder (
        .axil_if           ( axil_if ),
        .cache_axil_if     ( cache_axil_if ),
        .htable_axil_if    ( htable_axil_if ),
        .allocator_axil_if ( allocator_axil_if ),
        .db_axil_if        ( db_axil_if )
    );

    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( cache_axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( cache_axil_if__clk )
    );

    state_cache_reg_blk i_state_cache_reg_blk (
        .axil_if ( cache_axil_if__clk ),
        .reg_blk_if ( reg_if )
    );

    assign reg_if.info_size_nxt = NUM_IDS;
    assign reg_if.info_size_nxt_v = 1'b1;

    // Block control
    std_block_control i_std_block_control (
        .ctrl_clk       ( clk ),
        .ctrl_reset_in  ( reg_if.control.reset ),
        .ctrl_enable_in ( reg_if.control.enable ),
        .blk_clk        ( clk ),
        .blk_reset_out  ( ctrl_reset ),
        .blk_enable_out ( ctrl_en )
    );

    // Block monitoring
    std_block_monitor i_std_block_monitor (
        .blk_clk             ( clk ),
        .blk_reset_mon_in    ( __srst ),
        .blk_enable_mon_in   ( __en ),
        .blk_ready_mon_in    ( init_done ),
        .blk_state_mon_in    ( delete_state_mon_in ),
        .ctrl_clk            ( clk ),
        .ctrl_reset_mon_out  ( reg_if.status_nxt.reset_mon ),
        .ctrl_enable_mon_out ( reg_if.status_nxt.enable_mon),
        .ctrl_ready_mon_out  ( reg_if.status_nxt.ready_mon ),
        .ctrl_state_mon_out  ( delete_state_mon_out )
    );
    assign reg_if.status_nxt_v = 1'b1;

    assign delete_state_mon_in = {5'b0, delete_state};
    assign reg_if.dbg_delete_status_nxt_v = 1'b1;
    assign reg_if.dbg_delete_status_nxt.state = state_cache_reg_pkg::fld_dbg_delete_status_state_t'(delete_state_mon_out);

    // Block reset
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || ctrl_reset) __srst <= 1'b1;
        else                    __srst <= 1'b0;
    end

    // Block enable
    initial __en = 1'b0;
    always @(posedge clk) begin
        if (en && ctrl_en) __en <= 1'b1;
        else               __en <= 1'b0;
    end

    // ----------------------------------
    // Hash table core
    // ----------------------------------
    // AXI-L control
    db_axil_ctrl    #(
        .KEY_T       ( KEY_T ),
        .VALUE_T     ( ID_T )
    ) i_db_axil_ctrl__htable (
        .clk         ( clk ),
        .srst        ( __srst ),
        .init_done   ( htable_init_done ),
        .axil_if     ( db_axil_if ),
        .ctrl_reset  ( htable_ctrl_reset ),
        .ctrl_en     ( htable_ctrl_en ),
        .reset_mon   ( htable_srst ),
        .en_mon      ( htable_en ),
        .ready_mon   ( htable_init_done ),
        .info_if     ( htable_info_if ),
        .ctrl_if     ( htable_ctrl_if ),
        .status_if   ( htable_status_if )
    );

    // Block reset
    initial htable_srst = 1'b1;
    always @(posedge clk) begin
        if (__srst || htable_ctrl_reset) htable_srst <= 1'b1;
        else                             htable_srst <= 1'b0;
    end

    // Block enable
    initial htable_en = 1'b0;
    always @(posedge clk) begin
        if (__en && htable_ctrl_en) htable_en <= 1'b1;
        else                        htable_en <= 1'b0;
    end

    // Cuckoo hash
    htable_cuckoo_fast_update_core #(
        .KEY_T               ( KEY_T ),
        .VALUE_T             ( ID_T ),
        .NUM_TABLES          ( NUM_TABLES ),
        .TABLE_SIZE          ( TABLE_SIZE ),
        .HASH_LATENCY        ( HASH_LATENCY ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .UPDATE_BURST_SIZE   ( UPDATE_BURST_SIZE )
    ) i_htable_cuckoo_fast_update_core   (
        .clk                 ( clk ),
        .srst                ( htable_srst ),
        .en                  ( htable_en ),
        .init_done           ( htable_init_done ),
        .axil_if             ( htable_axil_if ),
        .info_if             ( htable_info_if ),
        .status_if           ( htable_status_if  ),
        .ctrl_if             ( htable_ctrl_if ),
        .lookup_if           ( htable_lookup_if ),
        .update_if           ( htable_update_if ),
        .lookup_key          ( lookup_key ),
        .lookup_hash         ( lookup_hash ),
        .ctrl_key            ( ctrl_key ),
        .ctrl_hash           ( ctrl_hash ),
        .tbl_init            ( tbl_init ),
        .tbl_init_done       ( tbl_init_done ),
        .tbl_wr_if           ( tbl_wr_if ),
        .tbl_rd_if           ( tbl_rd_if )
    );

    // ----------------------------------
    // ID allocator
    // ----------------------------------
    state_allocator_bv #(
        .ID_T           ( ID_T ),
        .NUM_IDS        ( NUM_IDS ),
        .ALLOC_FC       ( 0 ),
        .DEALLOC_FC     ( 1 ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_state_allocator_bv (
        .clk            ( clk ),
        .srst           ( __srst ),
        .init_done      ( allocator_init_done ),
        .en             ( __en ),
        .alloc_req      ( alloc_req ),
        .alloc_rdy      ( alloc_rdy ),
        .alloc_id       ( alloc_id ),
        .dealloc_req    ( dealloc_req ),
        .dealloc_rdy    ( dealloc_rdy ),
        .dealloc_id     ( dealloc_id ),
        .err_alloc      ( err_alloc ),
        .err_dealloc    ( err_dealloc ),
        .err_id         ( err_id ),
        .axil_if        ( allocator_axil_if )
    );

    assign alloc_req = insert_req && htable_update_if.rdy;

    assign dealloc_id = delete_id;

    // ----------------------------------
    // Lookup request context
    // ----------------------------------
    assign lookup_req_ctxt_in.key = lookup_if.key;
    assign lookup_req_ctxt_in.back_to_back = last_lookup_key_valid && (lookup_if.key == last_lookup_key);

    fifo_sync    #(
        .DATA_T   ( lookup_req_ctxt_t ),
        .DEPTH    ( NUM_RD_TRANSACTIONS ),
        .FWFT     ( 1 )
    ) i_fifo_sync__lookup_req_ctxt (
        .clk      ( clk ),
        .srst     ( htable_srst ),
        .wr_rdy   ( ),
        .wr       ( lookup_if.req && lookup_if.rdy ),
        .wr_data  ( lookup_req_ctxt_in ),
        .wr_count ( ),
        .full     ( ),
        .oflow    ( ),
        .rd       ( lookup_if.ack ),
        .rd_ack   ( ),
        .rd_data  ( lookup_req_ctxt_out ),
        .rd_count ( ),
        .empty    ( ),
        .uflow    ( )
    );

    // -----------------------------------------------------------
    // Latch last result (for back-to-back identical key handling)
    // -----------------------------------------------------------
    initial last_lookup_key_valid = 1'b0;
    always @(posedge clk) begin
        if (htable_srst)                         last_lookup_key_valid <= 1'b0;
        else if (lookup_if.req && lookup_if.rdy) last_lookup_key_valid <= 1'b1;
    end

    always_ff @(posedge clk) if (lookup_if.req && lookup_if.rdy) last_lookup_key <= lookup_if.key;


    initial last_lookup_valid = 1'b0;
    always @(posedge clk) begin
        if (htable_srst)        last_lookup_valid <= 1'b0;
        else if (lookup_if.ack) last_lookup_valid <= lookup_if.valid;
        else                    last_lookup_valid <= 1'b0;
    end
    
    // Latch last result
    always_ff @(posedge clk) if (lookup_if.ack) last_lookup_result <= lookup_if.value;

    assign back_to_back_lookup_valid = lookup_req_ctxt_out.back_to_back && last_lookup_valid;

    // ----------------------------------
    // Lookup interface
    // ----------------------------------
    assign htable_lookup_if.req = lookup_if.req;
    assign htable_lookup_if.key = lookup_if.key;

    assign lookup_if.rdy = htable_lookup_if.rdy;
    assign lookup_if.ack = htable_lookup_if.ack;
    assign lookup_if.error = htable_lookup_if.error;

    always_comb begin
        lookup_if.valid = 1'b0;
        lookup_result = '0;
        if (htable_lookup_if.valid) begin
            lookup_if.valid = 1'b1;
            lookup_result.id = htable_lookup_if.value;
            lookup_result._new = 1'b0;
        end else if (back_to_back_lookup_valid) begin
            lookup_if.valid = 1'b1;
            lookup_result.id = last_lookup_result.id;
            lookup_result._new = 1'b0;
        end else if (insert_rdy) begin
            lookup_if.valid = 1'b1;
            lookup_result.id = alloc_id;
            lookup_result._new = 1'b1;
        end
    end
    assign lookup_if.value = lookup_result;

    assign htable_lookup_if.next = 1'b0; // Not supported
    assign lookup_if.next_key = '0; // Not supported

    // ----------------------------------
    // Auto-insert
    // ----------------------------------
    // Synthesize insertion request
    assign insert_rdy   = htable_update_if.rdy && alloc_rdy;
    assign insert_req   = htable_lookup_if.ack && !htable_lookup_if.valid && !htable_lookup_if.error && !back_to_back_lookup_valid;
    assign insert_key   = lookup_req_ctxt_out.key;
    assign insert_id    = alloc_id;
    // Insertion status
    assign insert_done  = insert_req &&  insert_rdy;
    assign insert_error = insert_req && !insert_rdy;

    // ----------------------------------
    // Drive hash table update interface
    // ----------------------------------
    assign insert_sel = insert_req && alloc_rdy;

    assign delete_rdy = insert_sel ? 1'b0 : htable_update_if.rdy;

    assign htable_update_if.req = delete_req || (insert_req && alloc_rdy);
    assign htable_update_if.key = insert_sel ? insert_key : delete_key;
    assign htable_update_if.next  = 1'b0;
    assign htable_update_if.valid = insert_sel;
    assign htable_update_if.value = insert_sel? insert_id : delete_id;

    // ----------------------------------
    // Reverse (ID-to-key) mapping
    // ----------------------------------
    mem_ram_sdp_sync   #(
        .ADDR_WID       ( ID_WID ),
        .DATA_WID       ( KEY_WID ),
        .RESET_FSM      ( 1 ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_ram_sdp_sync__rev_map (
        .clk            ( clk ),
        .srst           ( __srst ),
        .init_done      ( revmap_init_done ),
        .mem_wr_if      ( revmap_wr_if ),
        .mem_rd_if      ( revmap_rd_if )
    );

    assign revmap_wr_if.rst = 1'b0;
    assign revmap_wr_if.en = 1'b1;
    assign revmap_wr_if.req = htable_update_if.req;
    assign revmap_wr_if.addr = htable_update_if.value;
    assign revmap_wr_if.data = htable_update_if.key;

    assign revmap_rd_if.rst = 1'b0;
    assign revmap_rd_if.en = 1'b1; // Unused
    assign revmap_rd_if.req = revmap_rd_req;
    assign revmap_rd_if.addr = delete_id;

    // ----------------------------------
    // Deletion FSM
    // ----------------------------------
    initial delete_state = DELETE_RESET;
    always @(posedge clk) begin
        if (__srst) delete_state <= DELETE_RESET;
        else        delete_state <= nxt_delete_state;
    end

    always_comb begin
        nxt_delete_state = delete_state;
        delete_if_rdy = 1'b0;
        revmap_rd_req = 1'b0;
        delete_req = 1'b0;
        dealloc_req = 1'b0;
        delete_done = 1'b0;
        delete_error = 1'b0;
        case (delete_state)
            DELETE_RESET : begin
                nxt_delete_state = DELETE_IDLE;
            end
            DELETE_IDLE : begin
                delete_if_rdy = 1'b1;
                if (delete_if.req) nxt_delete_state = DELETE_REVMAP_REQ;
            end
            DELETE_REVMAP_REQ : begin
                revmap_rd_req = 1'b1;
                if (revmap_rd_if.rdy) nxt_delete_state = DELETE_REVMAP_PENDING;
            end
            DELETE_REVMAP_PENDING : begin
                if (revmap_rd_if.ack) nxt_delete_state = DELETE_REQ;
            end
            DELETE_REQ : begin
                delete_req = 1'b1;
                if (delete_rdy) nxt_delete_state = DELETE_DEALLOC_ID;
            end
            DELETE_DEALLOC_ID : begin
                dealloc_req = 1'b1;
                if (dealloc_rdy) nxt_delete_state = DELETE_DONE;
            end
            DELETE_DONE : begin
                delete_done = 1'b1;
                nxt_delete_state = DELETE_IDLE;
            end
            DELETE_ERROR : begin
                delete_error = 1'b1;
                nxt_delete_state = DELETE_IDLE;
            end
            default : begin
                nxt_delete_state = DELETE_IDLE;
            end
        endcase
    end

    // Latch delete context (ID)
    always_ff @(posedge clk) if (delete_if.req && delete_if.rdy) delete_id <= delete_if.key;

    // Latch delete_context (key)
    always_ff @(posedge clk) if (revmap_rd_if.ack) delete_key <= revmap_rd_if.data;

    // Drive delete interface
    assign delete_if.rdy = delete_if_rdy;
    assign delete_if.ack = (delete_done || delete_error);
    assign delete_if.error = delete_error;
    assign delete_if.valid = 1'b1;
    assign delete_if.value = delete_key;

    // -----------------------------
    // Counters
    // -----------------------------
    logic __req;
    logic __tracked_existing;
    logic __tracked_new;
    logic __not_tracked;

    logic cnt_latch;
    logic cnt_clear;

    logic [63:0] cnt_req;
    logic [63:0] cnt_tracked_existing;
    logic [63:0] cnt_tracked_new;
    logic [63:0] cnt_not_tracked;

    // Synthesize (and buffer) counter update signals
    always_ff @(posedge clk) begin
        __req <= 1'b0;
        __tracked_new <= 1'b0;
        __tracked_existing <= 1'b0;
        __not_tracked <= 1'b0;
        if (lookup_if.ack) begin
            __req <= 1'b1;
            if (lookup_if.valid) begin
                if (insert_done) __tracked_new <= 1'b1;
                else             __tracked_existing <= 1'b1;
            end else             __not_tracked <= 1'b1;
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

    // Requests
    always_ff @(posedge clk) begin
        if (cnt_clear)  cnt_req <= 0;
        else if (__req) cnt_req <= cnt_req + 1;
    end
    // Tracked (existing)
    always_ff @(posedge clk) begin
        if (cnt_clear)               cnt_tracked_existing <= 0;
        else if (__tracked_existing) cnt_tracked_existing <= cnt_tracked_existing + 1;
    end
    // Tracked (new)
    always_ff @(posedge clk) begin
        if (cnt_clear)          cnt_tracked_new <= 0;
        else if (__tracked_new) cnt_tracked_new <= cnt_tracked_new + 1;
    end
    // Not tracked
    always_ff @(posedge clk) begin
        if (cnt_clear)          cnt_not_tracked <= 0;
        else if (__not_tracked) cnt_not_tracked <= cnt_not_tracked + 1;
    end

    assign reg_if.cnt_req_upper_nxt_v              = cnt_latch;
    assign reg_if.cnt_req_lower_nxt_v              = cnt_latch;
    assign reg_if.cnt_tracked_existing_upper_nxt_v = cnt_latch;
    assign reg_if.cnt_tracked_existing_lower_nxt_v = cnt_latch;
    assign reg_if.cnt_tracked_new_upper_nxt_v      = cnt_latch;
    assign reg_if.cnt_tracked_new_lower_nxt_v      = cnt_latch;
    assign reg_if.cnt_not_tracked_upper_nxt_v      = cnt_latch;
    assign reg_if.cnt_not_tracked_lower_nxt_v      = cnt_latch;

    assign {reg_if.cnt_req_upper_nxt,              reg_if.cnt_req_lower_nxt}              = cnt_req;
    assign {reg_if.cnt_tracked_existing_upper_nxt, reg_if.cnt_tracked_existing_lower_nxt} = cnt_tracked_existing;
    assign {reg_if.cnt_tracked_new_upper_nxt,      reg_if.cnt_tracked_new_lower_nxt}      = cnt_tracked_new;
    assign {reg_if.cnt_not_tracked_upper_nxt,      reg_if.cnt_not_tracked_lower_nxt}      = cnt_not_tracked;

endmodule : state_cache_core

