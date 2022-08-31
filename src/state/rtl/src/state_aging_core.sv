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
module state_aging_core #(
    parameter type ID_T = logic[15:0],
    parameter type TIMER_T = logic[15:0],
    parameter int  TS_PER_TICK = 10**3, // Conversion factor describing # of
                                        // input ts_clk cycles ticks comprising
                                        // one output timer tick
                                        // e.g. for microsecond timestamp clock,
                                        // TS_PER_TICK = 10**3
                                        // yields tick period of 1ms
    parameter bit  TS_CLK_DDR = 1,      // TS_CLK_DDR == 1: Process both positive and
                                        //   negative edges of ts_clk (consistent with
                                        //   generating the clock from the LSb of a timestamp)
                                        // TS_CLK_DDR == 0: Process positive edges of ts_clk only
    parameter bit  VALID_TRACKING = 1'b1
)(
    // Clock/reset
    input  logic               clk,
    input  logic               srst,

    output logic               init_done,

    // Timestamp clock
    input  logic               ts_clk,

    // Config
    input  TIMER_T             cfg_timeout,

    // AXI-L debug interface
    axi4l_intf.peripheral      axil_if,

    // Control interface
    db_ctrl_intf.peripheral    ctrl_if,

    // Timeout event notification feed
    std_event_intf.publisher   notify_if,

    // Update interface
    db_intf.responder          update_if
);

    // -----------------------------
    // Imports
    // -----------------------------
    import state_pkg::*;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic [3:0] {
        RESET         = 0,
        IDLE          = 1,
        VALID_RD_REQ  = 2,
        VALID_RD_WAIT = 3,
        TIMER_RD_REQ  = 4,
        TIMER_RD_WAIT = 5,
        CHECK         = 6,
        NOTIFY        = 7,
        DONE          = 8
    } state_t;

    typedef logic dummy_t;

    // -----------------------------
    // Signals
    // -----------------------------
    logic en;

    logic local_srst__unbuffered;
    logic local_srst;
    logic valid_core_init_done;
    logic timer_core_init_done;

    logic tick;

    state_t state;
    state_t nxt_state;

    logic rd_valid;
    logic rd_timer;
    logic notify;

    TIMER_T __cfg_timeout;
    logic expiry;

    ID_T  id;
    logic reset_id;
    logic inc_id;

    logic activate;
    logic deactivate;

    // -----------------------------
    // Interfaces
    // -----------------------------
    db_intf #(.KEY_T(ID_T), .VALUE_T(TIMER_T))       timer_read_if (.clk(clk));
    db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(dummy_t))  local_ctrl_if (.clk(clk));

    state_aging_core_reg_intf reg_if ();

    axi4l_intf #() axil_if__clk ();

    // -----------------------------
    // Register block
    // -----------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    // Registers
    state_aging_core_reg_blk i_state_aging_core_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );
    
    // Export parameterization info to regmap
    assign reg_if.info_size_nxt_v = 1'b1;
    assign reg_if.info_size_nxt = 2**$bits(ID_T);

    assign reg_if.info_timer_bits_nxt_v = 1'b1;
    assign reg_if.info_timer_bits_nxt = $bits(TIMER_T);

    assign reg_if.info_timer_ratio_nxt_v = 1'b1;
    assign reg_if.info_timer_ratio_nxt = TS_PER_TICK;

    // Block-level reset control
    assign local_srst__unbuffered = srst || reg_if.control.reset;

    initial local_srst = 1'b1;
    always @(posedge clk) begin
        if (local_srst__unbuffered) local_srst <= 1'b1;
        else                        local_srst <= 1'b0;
    end

    // Report status
    assign reg_if.status_nxt_v = 1'b1;
    always_ff @(posedge clk) begin
        reg_if.status_nxt.reset <= local_srst;
        reg_if.status_nxt.init_done <= init_done;
    end

    // -----------------------------
    // Logic
    // -----------------------------
    generate
        // Track valid/invalid (enabled/disabled) status for each entry
        // (expiry is only reported for valid entries)
        if (VALID_TRACKING) begin : g__valid_tracking
            db_ctrl_intf #(.KEY_T(ID_T), .VALUE_T(dummy_t)) valid_ctrl_if (.clk(clk));

            // Mux between local and external control interfaces
            db_ctrl_intf_prio_mux  i_db_ctrl_intf_prio_mux (
                .clk ( clk ),
                .srst ( local_srst ),
                .ctrl_if_from_controller_hi_prio ( ctrl_if ),
                .ctrl_if_from_controller_lo_prio ( local_ctrl_if ),
                .ctrl_if_to_peripheral           ( valid_ctrl_if )
            );

            // -----------------------------
            // Active/inactive entry management
            // -----------------------------
            state_valid_core #(
                .ID_T      ( ID_T )
            ) i_state_valid_core (
                .clk       ( clk ),
                .srst      ( local_srst__unbuffered ),
                .init_done ( valid_core_init_done ),
                .ctrl_if   ( valid_ctrl_if )
            );

            // ----------------------------------
            // Drive valid read interface
            // ----------------------------------
            assign local_ctrl_if.req = rd_valid;
            assign local_ctrl_if.key = id;
            assign local_ctrl_if.command = db_pkg::COMMAND_GET;
            assign local_ctrl_if.set_value = '0;

            // ----------------------------------
            // Synthesize activate/deactivate flags for debug counters
            // ----------------------------------
            initial begin
                activate = 1'b0;
                deactivate = 1'b0;
            end
            always @(posedge clk) begin
                if (local_srst) begin
                    activate <= 1'b0;
                    deactivate <= 1'b0;
                end else begin
                    activate <= 1'b0;
                    deactivate <= 1'b0;
                    if (valid_ctrl_if.req && valid_ctrl_if.rdy) begin
                        if (valid_ctrl_if.command == db_pkg::COMMAND_SET)   activate   <= 1'b1;
                        if (valid_ctrl_if.command == db_pkg::COMMAND_UNSET) deactivate <= 1'b1;
                    end
                end
            end

        end : g__valid_tracking
        // Don't track valid/invalid (enabled/disabled) status for each entry
        // (expiry is reported for all entries)
        else begin : g__no_valid_tracking
            // Terminate control interfaces
            db_ctrl_intf_peripheral_term i_db_ctrl_intf_peripheral_term (.ctrl_if (ctrl_if));
            db_ctrl_intf_controller_term i_db_ctrl_intf_controller_term (.ctrl_if (local_ctrl_if));

            assign activate = 1'b0;
            assign deactivate = 1'b0;

            assign valid_core_init_done = 1'b1;
        end : g__no_valid_tracking
    endgenerate

    // -----------------------------
    // Timer tick synthesis
    // -----------------------------
    state_timer_tick #(
        .TS_PER_TICK  ( TS_PER_TICK ),
        .TS_CLK_DDR   ( TS_CLK_DDR )
    ) i_state_timer_tick (
        .clk     ( clk ),
        .srst    ( local_srst ),
        .squelch ( 1'b0 ),
        .ts_clk  ( ts_clk ),
        .tick    ( tick )
    );
    
    // -----------------------------
    // Timers
    // -----------------------------
    state_timer_core #(
        .ID_T      ( ID_T ),
        .TIMER_T   ( TIMER_T )
    ) i_state_timer_core (
        .clk       ( clk ),
        .srst      ( local_srst__unbuffered ),
        .init_done ( timer_core_init_done ),
        .tick      ( tick ),
        .read_if   ( timer_read_if ),
        .update_if ( update_if )
    );

    // -----------------------------
    // Disable when cfg_timeout == 0
    // -----------------------------
    always_ff @(posedge clk) en <= reg_if.control.enable && (cfg_timeout > 0);

    // -----------------------------
    // Init done reporting
    // - wait for memory initialization to complete
    // -----------------------------
    assign init_done = valid_core_init_done && timer_core_init_done;

    // -----------------------------
    // Aging state machine
    // -----------------------------
    initial state = RESET;
    always @(posedge clk) begin
        if (local_srst) state <= RESET;
        else            state <= nxt_state;
    end

    always_comb begin
        nxt_state = state;
        rd_valid = 1'b0;
        rd_timer = 1'b0;
        notify = 1'b0;
        inc_id = 1'b0;
        reset_id = 1'b0;
        case (state)
            RESET : begin
                reset_id = 1'b1;
                nxt_state = IDLE;
            end
            IDLE : begin
                if (en) begin
                    if (VALID_TRACKING) nxt_state = VALID_RD_REQ;
                    else                nxt_state = TIMER_RD_REQ;
                end
            end
            VALID_RD_REQ : begin
                rd_valid = 1'b1;
                if (local_ctrl_if.rdy) nxt_state = VALID_RD_WAIT;
            end
            VALID_RD_WAIT : begin
                if (local_ctrl_if.ack) begin
                    if (local_ctrl_if.valid) nxt_state = TIMER_RD_REQ;
                    else                     nxt_state = DONE;
                end
            end
            TIMER_RD_REQ : begin
                rd_timer = 1'b1;
                if (timer_read_if.rdy) nxt_state = TIMER_RD_WAIT;
            end
            TIMER_RD_WAIT : begin
                if (timer_read_if.ack) nxt_state = CHECK;
            end
            CHECK : begin
                if (expiry) nxt_state = NOTIFY;
                else        nxt_state = DONE;
            end
            NOTIFY : begin
                notify = 1'b1;
                nxt_state = DONE;
            end
            DONE : begin
                inc_id = 1'b1;
                nxt_state = IDLE;
            end
        endcase
    end

    // -----------------------------
    // ID management
    // -----------------------------
    initial id = 0;
    always @(posedge clk) begin
        if (reset_id)    id <= 0;
        else if (inc_id) id <= id + 1;
    end

    // ----------------------------------
    // Drive timer read interface
    // ----------------------------------
    assign timer_read_if.req = rd_timer;
    assign timer_read_if.key = id;

    // ---------------------------------------------------
    // Process read result
    //   - compare stored timestamp to current time
    //   - issue timeout notification (idle/active) where
    //     elapsed time exceeds configured threshold
    // ---------------------------------------------------
    // Pipeline timeout threshold input
    always_ff @(posedge clk) __cfg_timeout <= cfg_timeout;

    initial expiry = 1'b0;
    always @(posedge clk) begin
        if (local_srst)             expiry <= 1'b0;
        else if (timer_read_if.ack) expiry <= (timer_read_if.value >= __cfg_timeout);
    end

    initial notify_if.evt = 1'b0;
    always @(posedge clk) begin
        if (local_srst) notify_if.evt <= 1'b0;
        else            notify_if.evt <= notify;
    end

    always_ff @(posedge clk) notify_if.msg <= id;

    // ----------------------------------
    // Debug status
    // ----------------------------------
    // State
    assign reg_if.dbg_status_nxt_v = 1'b1;
    assign reg_if.dbg_status_nxt.state = state;

    // Counters
    // -- function-level reset
    logic dbg_cnt_reset;
    initial dbg_cnt_reset = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset || reg_if.dbg_control.clear_counts) dbg_cnt_reset <= 1'b1;
        else                                                                 dbg_cnt_reset <= 1'b0;
    end
    // -- update logic
    always_comb begin
        // Default is no update
        reg_if.dbg_cnt_timer_nxt_v  = 1'b0;
        reg_if.dbg_cnt_active_nxt_v = 1'b0;
        reg_if.dbg_cnt_notify_nxt_v = 1'b0;
        // Next counter values (default to previous counter values)
        reg_if.dbg_cnt_timer_nxt  = reg_if.dbg_cnt_timer;
        reg_if.dbg_cnt_active_nxt = reg_if.dbg_cnt_active;
        reg_if.dbg_cnt_notify_nxt = reg_if.dbg_cnt_notify;
        if (dbg_cnt_reset) begin
            // Update on reset/clear
            reg_if.dbg_cnt_timer_nxt_v  = 1'b1;
            reg_if.dbg_cnt_active_nxt_v = 1'b1;
            reg_if.dbg_cnt_notify_nxt_v = 1'b1;
            // Clear counts
            reg_if.dbg_cnt_timer_nxt  = 0;
            reg_if.dbg_cnt_active_nxt = 0;
            reg_if.dbg_cnt_notify_nxt = 0;
        end else begin
            // Selectively update
            if (tick)                  reg_if.dbg_cnt_timer_nxt_v  = 1'b1;
            if (notify)                reg_if.dbg_cnt_notify_nxt_v = 1'b1;
            if (activate ^ deactivate) reg_if.dbg_cnt_active_nxt_v = 1'b1;
            // Increment-by-one counters
            reg_if.dbg_cnt_timer_nxt                       = reg_if.dbg_cnt_timer  + 1;
            reg_if.dbg_cnt_notify_nxt                      = reg_if.dbg_cnt_notify + 1;
            // Increment/decrement counters
            if (activate)        reg_if.dbg_cnt_active_nxt = reg_if.dbg_cnt_active + 1;
            else if (deactivate) reg_if.dbg_cnt_active_nxt = reg_if.dbg_cnt_active - 1; 
        end
    end
 
endmodule : state_aging_core
