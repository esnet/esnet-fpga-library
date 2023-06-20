module timer_expiry #(
    parameter type TIMER_T = logic
)(
    // Clock/reset
    input  logic   clk,
    input  logic   srst,

    // Control
    input  logic   en,
    input  logic   reset,
    input  logic   freeze,
    
    // Timer control
    input  logic   tick,

    // Configuration
    axi4l_intf.peripheral axil_if,

    // Check interface
    input  TIMER_T timer_in,
    output logic   expired,

    // Update interface
    output TIMER_T timer_out
);

    // -----------------------------
    // Signals
    // -----------------------------
    logic __srst;
    logic __en;

    logic __freeze;

    TIMER_T timer;
    
    TIMER_T timeout;
    TIMER_T __timeout_thresh;
    logic signed [$bits(TIMER_T)-1:0] time_delta;

    // -----------------------------
    // Interfaces
    // -----------------------------
    axi4l_intf axil_if__clk ();
    timer_expiry_reg_intf reg_if ();

    // -----------------------------
    // AXI-L control
    // -----------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    timer_expiry_reg_blk i_timer_expiry_reg_blk (
        .axil_if ( axil_if__clk ),
        .reg_blk_if ( reg_if )
    );
    
    // Info
    assign reg_if.info_timer_bits_nxt_v = 1'b1;
    assign reg_if.info_timer_bits_nxt = $bits(TIMER_T);

    // Control
    initial __srst = 1'b1;
    always @(posedge clk) begin
        if (srst || reg_if.control.reset) __srst <= 1'b1;
        else                              __srst <= 1'b0;
    end

    initial __en = 1'b1;
    always @(posedge clk) begin
        if (en && reg_if.control.enable) __en <= 1'b1;
        else                             __en <= 1'b0;
    end

    assign __freeze = freeze || reg_if.control.freeze;

    // Status
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset_mon = __srst;
    assign reg_if.status_nxt.enable_mon = __en;
    assign reg_if.status_nxt.ready_mon = !__srst;

    // Config
    assign timeout = reg_if.cfg_timeout[$bits(TIMER_T)-1:0];
    always_ff @(posedge clk) __timeout_thresh <= timer - timeout;

    // ----------------------------------
    // Timer
    // ----------------------------------
    timer #(
        .TIMER_T ( TIMER_T )
    ) i_timer (
        .clk ( clk ),
        .srst ( __srst ),
        .reset ( reset ),
        .freeze ( __freeze ),
        .tick ( tick ),
        .timer ( timer )
    );
 
    // ----------------------------------
    // Drive expiry interface
    // ----------------------------------
    assign time_delta = timer_in - __timeout_thresh;
    assign expired = time_delta <= 0;
 
    // ----------------------------------
    // Drive update interface
    // ----------------------------------
    // Keep timer output synchronized with expiration calculation
    always_ff @(posedge clk) timer_out <= timer;

    // ----------------------------------
    // Debug status
    // ----------------------------------
    assign reg_if.dbg_timer_upper_nxt_v = 1'b1;
    assign reg_if.dbg_timer_lower_nxt_v = 1'b1;
    assign {reg_if.dbg_timer_upper_nxt, reg_if.dbg_timer_lower_nxt} = {'0, timer};

endmodule : timer_expiry
