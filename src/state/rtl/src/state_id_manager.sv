module state_id_manager
#(
    parameter type KEY_T = logic,
    parameter type ID_T = logic,
    parameter int  NUM_IDS = 2**$bits(ID_T), // Must be equal to or less than 2**$bits(ID_T)
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1 // Optimize sim time by performing fast memory init
)(
    // Clock/reset
    input  logic           clk,
    input  logic           srst,

    input  logic           en,

    output logic           init_done,

    // Insert interface (from application) : Store entry associating ID with KEY
    output logic           insert_rdy,
    input  logic           insert_req,
    input  KEY_T           insert_key,
    output ID_T            insert_id,

    // Delete interface (from application) : Delete entry corresponding to ID
    db_intf.responder      delete_by_id_if,

    // Delete interface (to application): Delete entry corresponding to KEY
    db_intf.requester      delete_by_key_if,

    // AXI-L control interface
    axi4l_intf.peripheral  axil_if,

    // Status
    output logic [7:0]     delete_state_mon
);

    // ----------------------------------
    // Parameters
    // ----------------------------------
    localparam int ID_WID = $bits(ID_T);
    localparam int KEY_WID = $bits(KEY_T);

    // -----------------------------
    // Parameter checks
    // -----------------------------
    initial begin
        std_pkg::param_check($bits(delete_by_id_if.KEY_T), ID_WID, "delete_by_id_if.KEY_T");
        std_pkg::param_check($bits(delete_by_id_if.VALUE_T), KEY_WID, "delete_by_id_if.VALUE_T");
        std_pkg::param_check($bits(delete_by_key_if.KEY_T), KEY_WID, "delete_by_id_if.KEY_T");
        std_pkg::param_check($bits(delete_by_key_if.VALUE_T), ID_WID, "delete_by_id_if.VALUE_T");
        std_pkg::param_check_lt(NUM_IDS, 2**$bits(ID_T), "NUM_IDS");
    end

    // ----------------------------------
    // Typedefs
    // ----------------------------------
    typedef enum logic [3:0] {
        DELETE_RESET          = 0,
        DELETE_IDLE           = 1,
        DELETE_REVMAP_REQ     = 2,
        DELETE_REVMAP_PENDING = 3,
        DELETE_REQ            = 4,
        DELETE_PENDING        = 5,
        DELETE_DEALLOC_ID     = 6,
        DELETE_DONE           = 7,
        DELETE_ERROR          = 8
    } delete_state_t;

    // ----------------------------------
    // Signals
    // ----------------------------------
    logic init_done__allocator;
    logic init_done__revmap;

    logic alloc_req;
    logic alloc_rdy;
    ID_T  alloc_id;

    logic dealloc_req;
    logic dealloc_rdy;
    ID_T  dealloc_id;

    ID_T  delete_id;
    KEY_T delete_key;

    delete_state_t delete_state;
    delete_state_t nxt_delete_state;

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    mem_wr_intf #(.ADDR_WID(ID_WID), .DATA_WID(KEY_WID)) revmap_wr_if (.clk(clk));
    mem_rd_intf #(.ADDR_WID(ID_WID), .DATA_WID(KEY_WID)) revmap_rd_if (.clk(clk));

    // ----------------------------------
    // Status
    // ----------------------------------
    assign init_done = init_done__allocator && init_done__revmap;

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
        .srst           ( srst ),
        .init_done      ( init_done__allocator ),
        .en             ( en ),
        .alloc_req      ( alloc_req ),
        .alloc_rdy      ( alloc_rdy ),
        .alloc_id       ( alloc_id ),
        .dealloc_req    ( dealloc_req ),
        .dealloc_rdy    ( dealloc_rdy ),
        .dealloc_id     ( dealloc_id ),
        .err_alloc      ( ),
        .err_dealloc    ( ),
        .err_id         ( ),
        .axil_if        ( axil_if )
    );

    assign alloc_req = insert_req && insert_rdy;

    assign insert_rdy = revmap_wr_if.rdy && alloc_rdy;
    assign insert_id = alloc_id;

    assign dealloc_id = delete_id;

    // ----------------------------------
    // Reverse (ID-to-key) mapping table
    // ----------------------------------
    localparam mem_pkg::spec_t MEM_SPEC = '{
        ADDR_WID: ID_WID,
        DATA_WID: KEY_WID,
        ASYNC: 0,
        RESET_FSM: 1,
        OPT_MODE: mem_pkg::OPT_MODE_TIMING
    };

    mem_ram_sdp        #(
        .SPEC           ( MEM_SPEC ),
        .SIM__FAST_INIT ( SIM__FAST_INIT )
    ) i_mem_ram_sdp__rev_map (
        .mem_wr_if      ( revmap_wr_if ),
        .mem_rd_if      ( revmap_rd_if )
    );

    assign init_done__revmap = revmap_wr_if.rdy;

    assign revmap_wr_if.rst = srst;
    assign revmap_wr_if.en = 1'b1;
    assign revmap_wr_if.req = insert_req && insert_rdy;
    assign revmap_wr_if.addr = insert_id;
    assign revmap_wr_if.data = insert_key;

    assign revmap_rd_if.rst = 1'b0;
    assign revmap_rd_if.addr = delete_id;

    // Latch delete context (ID)
    always_ff @(posedge clk) if (delete_by_id_if.req && delete_by_id_if.rdy) delete_id <= delete_by_id_if.key;

    assign delete_by_id_if.valid = 1'b1;
    assign delete_by_id_if.value = delete_key;
    assign delete_by_id_if.next_key = '0; // Unused

    // Latch delete context (KEY)
    always_ff @(posedge clk) if (revmap_rd_if.ack) delete_key <= revmap_rd_if.data;

    assign delete_by_key_if.key = delete_key;
    assign delete_by_key_if.valid = 1'b0;
    assign delete_by_key_if.next = 1'b0; // Unused

    // ----------------------------------
    // Deletion FSM
    // ----------------------------------
    initial delete_state = DELETE_RESET;
    always @(posedge clk) begin
        if (srst) delete_state <= DELETE_RESET;
        else      delete_state <= nxt_delete_state;
    end

    always_comb begin
        nxt_delete_state = delete_state;
        delete_by_id_if.rdy = 1'b0;
        revmap_rd_if.req = 1'b0;
        delete_by_key_if.req = 1'b0;
        dealloc_req = 1'b0;
        delete_by_id_if.ack = 1'b0;
        delete_by_id_if.error = 1'b0;
        case (delete_state)
            DELETE_RESET : begin
                nxt_delete_state = DELETE_IDLE;
            end
            DELETE_IDLE : begin
                delete_by_id_if.rdy = 1'b1;
                if (delete_by_id_if.req) nxt_delete_state = DELETE_REVMAP_REQ;
            end
            DELETE_REVMAP_REQ : begin
                revmap_rd_if.req = 1'b1;
                if (revmap_rd_if.rdy) nxt_delete_state = DELETE_REVMAP_PENDING;
            end
            DELETE_REVMAP_PENDING : begin
                if (revmap_rd_if.ack) nxt_delete_state = DELETE_REQ;
            end
            DELETE_REQ : begin
                delete_by_key_if.req = 1'b1;
                if (delete_by_key_if.rdy) nxt_delete_state = DELETE_PENDING;
            end
            DELETE_PENDING : begin
                if (delete_by_key_if.ack) begin
                    if (delete_by_key_if.error) nxt_delete_state = DELETE_ERROR;
                    else nxt_delete_state = DELETE_DEALLOC_ID;
                end
            end
            DELETE_DEALLOC_ID : begin
                dealloc_req = 1'b1;
                if (dealloc_rdy) nxt_delete_state = DELETE_DONE;
            end
            DELETE_DONE : begin
                delete_by_id_if.ack = 1'b1;
                nxt_delete_state = DELETE_IDLE;
            end
            DELETE_ERROR : begin
                delete_by_id_if.ack = 1'b1;
                delete_by_id_if.error = 1'b1;
                nxt_delete_state = DELETE_IDLE;
            end
            default : begin
                nxt_delete_state = DELETE_IDLE;
            end
        endcase
    end

    assign delete_state_mon = {'0, delete_state};

endmodule : state_id_manager
