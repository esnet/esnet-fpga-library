// Allocator AXI-L control/monitoring core
//
// Implements (common) control and monitoring functions for alloc components,
// including terminating register interface, maintaining counts, etc.
module alloc_axil_core #(
    parameter type PTR_T = logic
) (
    // Clock/reset
    input logic               clk,
    input logic               srst,

    // Control (in)
    input  logic              en,

    // Control (out)
    output logic              ctrl_reset,
    output logic              ctrl_en,
    output logic              ctrl_alloc_en,
    
    // Status
    input  logic              init_done,
    input  logic [7:0]        state_mon [2],

    // Monitor interface
    alloc_mon_intf.rx         mon_if,

    // AXI-L control/monitoring
    axi4l_intf.peripheral     axil_if
);

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int MAX_PTRS = 2**$bits(PTR_T);

    // -----------------------------
    // Signals
    // -----------------------------
    logic dbg_cnt_reset;

    // -----------------------------
    // Interfaces
    // -----------------------------
    alloc_mon_intf __mon_if (.clk);
    axi4l_intf axil_if__clk ();

    alloc_reg_intf reg_if ();

    // -----------------------------
    // Pipeline monitor interface
    // -----------------------------
    alloc_mon_pipe_auto i_alloc_mon_pipe_auto (
        .from_tx ( mon_if ),
        .to_rx   ( __mon_if )
    );

    // -----------------------------
    // AXI-L register block
    // -----------------------------
    // Pass AXI-L interface from aclk (AXI-L clock) to clk domain
    axi4l_intf_cdc i_axil_intf_cdc (
        .axi4l_if_from_controller   ( axil_if ),
        .clk_to_peripheral          ( clk ),
        .axi4l_if_to_peripheral     ( axil_if__clk )
    );

    // Registers
    alloc_reg_blk i_alloc_reg_blk (
        .axil_if    ( axil_if__clk ),
        .reg_blk_if ( reg_if ) 
    );

    // Export parameterization info to regmap
    assign reg_if.info_size_nxt_v = 1'b1;
    assign reg_if.info_size_nxt = MAX_PTRS;

    // ----------------------------------
    // Control
    // ----------------------------------
    util_reset_buffer i_util_reset_buffer (
        .clk,
        .srst_in   ( srst || reg_if.control.reset ),
        .srst_out  ( ctrl_reset )
    );

    always_ff @(posedge clk) ctrl_en <= en && reg_if.control.enable;

    assign ctrl_alloc_en = reg_if.control.allocate_en;

    // ----------------------------------
    // Block monitoring
    // ----------------------------------
    assign reg_if.status_nxt_v = 1'b1;
    assign reg_if.status_nxt.reset = ctrl_reset;
    assign reg_if.status_nxt.init_done = init_done;
    assign reg_if.status_nxt.enabled = ctrl_en;

    // ----------------------------------
    // Status
    // ----------------------------------
    // Allocation/deallocation error flags

    assign reg_if.status_flags_nxt_v = 1'b1;
    always_comb begin
        if (reg_if.status_flags_rd_evt) begin
            reg_if.status_flags_nxt.alloc_err    = __mon_if.alloc_err;
            reg_if.status_flags_nxt.dealloc_err  = __mon_if.dealloc_err;
        end else begin
            reg_if.status_flags_nxt.alloc_err   = reg_if.status_flags.alloc_err | __mon_if.alloc_err;
            reg_if.status_flags_nxt.dealloc_err = reg_if.status_flags.dealloc_err | __mon_if.dealloc_err;
        end
    end

    // Latch value of pointer on error
    assign reg_if.alloc_err_ptr_nxt_v = __mon_if.alloc_err;
    assign reg_if.alloc_err_ptr_nxt   = __mon_if.ptr;

    assign reg_if.dealloc_err_ptr_nxt_v = __mon_if.dealloc_err;
    assign reg_if.dealloc_err_ptr_nxt   = __mon_if.ptr;
    
    // Maintain active (currently allocated) count
    always_comb begin
        reg_if.cnt_active_nxt_v = 1'b0;
        reg_if.cnt_active_nxt = reg_if.cnt_active;
        if (__mon_if.alloc ^ __mon_if.dealloc) reg_if.cnt_active_nxt_v = 1'b1;
        // Increment/decrement counters
        if (__mon_if.alloc)        reg_if.cnt_active_nxt = reg_if.cnt_active + 1;
        else if (__mon_if.dealloc) reg_if.cnt_active_nxt = reg_if.cnt_active - 1;
    end

    // ----------------------------------
    // Debug status
    // ----------------------------------
    // State monitoring
    assign reg_if.dbg_status_nxt_v = 1'b1;
    assign reg_if.dbg_status_nxt.state_0 = state_mon[0];
    assign reg_if.dbg_status_nxt.state_1 = state_mon[1];

    // Debug Counters (32-bit, non-saturating)
    // -- function-level reset
    util_reset_buffer i_util_reset_buffer__dbg_cnt (
        .clk,
        .srst_in   ( srst || reg_if.control.reset || reg_if.dbg_control.clear_counts ),
        .srst_out  ( dbg_cnt_reset )
    );

    always_comb begin
        // Default is no update
        reg_if.dbg_cnt_alloc_nxt_v        = 1'b0;
        reg_if.dbg_cnt_alloc_fail_nxt_v   = 1'b0;
        reg_if.dbg_cnt_alloc_err_nxt_v    = 1'b0;
        reg_if.dbg_cnt_dealloc_nxt_v      = 1'b0;
        reg_if.dbg_cnt_dealloc_fail_nxt_v = 1'b0;
        reg_if.dbg_cnt_dealloc_err_nxt_v  = 1'b0;
        // Next counter values (default to previous counter values)
        reg_if.dbg_cnt_alloc_nxt        = reg_if.dbg_cnt_alloc;
        reg_if.dbg_cnt_alloc_fail_nxt   = reg_if.dbg_cnt_alloc_fail;
        reg_if.dbg_cnt_alloc_err_nxt    = reg_if.dbg_cnt_alloc_err;
        reg_if.dbg_cnt_dealloc_nxt      = reg_if.dbg_cnt_dealloc;
        reg_if.dbg_cnt_dealloc_fail_nxt = reg_if.dbg_cnt_dealloc_fail;
        reg_if.dbg_cnt_dealloc_err_nxt  = reg_if.dbg_cnt_dealloc_err;
        if (dbg_cnt_reset) begin
            // Update on reset/clear
            reg_if.dbg_cnt_alloc_nxt_v        = 1'b1;
            reg_if.dbg_cnt_alloc_fail_nxt_v   = 1'b1;
            reg_if.dbg_cnt_alloc_err_nxt_v    = 1'b1;
            reg_if.dbg_cnt_dealloc_nxt_v      = 1'b1;
            reg_if.dbg_cnt_dealloc_fail_nxt_v = 1'b1;
            reg_if.dbg_cnt_dealloc_err_nxt_v  = 1'b1;
            // Clear counts
            reg_if.dbg_cnt_alloc_nxt        = 0;
            reg_if.dbg_cnt_alloc_fail_nxt   = 0;
            reg_if.dbg_cnt_alloc_err_nxt    = 0;
            reg_if.dbg_cnt_dealloc_nxt      = 0;
            reg_if.dbg_cnt_dealloc_fail_nxt = 0;
            reg_if.dbg_cnt_dealloc_err_nxt  = 0;
        end else begin
            // Selectively update
            if (__mon_if.alloc)        reg_if.dbg_cnt_alloc_nxt_v        = 1'b1;
            if (__mon_if.alloc_fail)   reg_if.dbg_cnt_alloc_fail_nxt_v   = 1'b1;
            if (__mon_if.alloc_err)    reg_if.dbg_cnt_alloc_err_nxt_v    = 1'b1;
            if (__mon_if.dealloc)      reg_if.dbg_cnt_dealloc_nxt_v      = 1'b1;
            if (__mon_if.dealloc_fail) reg_if.dbg_cnt_dealloc_fail_nxt_v = 1'b1;
            if (__mon_if.dealloc_err)  reg_if.dbg_cnt_dealloc_err_nxt_v  = 1'b1;
            // Increment-by-one counters
            reg_if.dbg_cnt_alloc_nxt        = reg_if.dbg_cnt_alloc        + 1;
            reg_if.dbg_cnt_alloc_fail_nxt   = reg_if.dbg_cnt_alloc_fail   + 1;
            reg_if.dbg_cnt_alloc_err_nxt    = reg_if.dbg_cnt_alloc_err    + 1;
            reg_if.dbg_cnt_dealloc_nxt      = reg_if.dbg_cnt_dealloc      + 1;
            reg_if.dbg_cnt_dealloc_fail_nxt = reg_if.dbg_cnt_dealloc_fail + 1;
            reg_if.dbg_cnt_dealloc_err_nxt  = reg_if.dbg_cnt_dealloc_err  + 1;
        end
    end

endmodule : alloc_axil_core
