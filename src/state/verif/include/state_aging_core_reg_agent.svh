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

class state_aging_core_reg_agent extends state_aging_core_reg_blk_agent;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="state_aging_core_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
    endfunction
 
    // Reset agent state
    // [[ implements std_verif_pkg::agent.reset() virtual method ]]
    function automatic void reset();
        super.reset();
        // Nothing extra to do
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        soft_reset();
    endtask

    task soft_reset();
        state_aging_core_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        state_aging_core_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset == 1'b1 || reg_status.init_done == 1'b0);
    endtask

    task get_size(output int size);
        state_aging_core_reg_pkg::reg_info_size_t reg_info_size;
        this.read_info_size(reg_info_size);
        size = reg_info_size;
    endtask

    task get_timer_bits(output int timer_bits);
        state_aging_core_reg_pkg::reg_info_timer_bits_t reg_info_timer_bits;
        this.read_info_timer_bits(reg_info_timer_bits);
        timer_bits = reg_info_timer_bits;
    endtask

    task get_timer_ratio(output int timer_ratio);
        state_aging_core_reg_pkg::reg_info_timer_ratio_t reg_info_timer_ratio;
        this.read_info_timer_ratio(reg_info_timer_ratio);
        timer_ratio = reg_info_timer_ratio;
    endtask

    task get_timer_cnt(output int cnt);
        state_aging_core_reg_pkg::reg_dbg_cnt_timer_t reg_dbg_cnt_timer;
        this.read_dbg_cnt_timer(reg_dbg_cnt_timer);
        cnt = reg_dbg_cnt_timer;
    endtask

    task get_active_cnt(output int cnt);
        state_aging_core_reg_pkg::reg_dbg_cnt_active_t reg_dbg_cnt_active;
        this.read_dbg_cnt_active(reg_dbg_cnt_active);
        cnt = reg_dbg_cnt_active;
    endtask

    task get_notify_cnt(output int cnt);
        state_aging_core_reg_pkg::reg_dbg_cnt_notify_t reg_dbg_cnt_notify;
        this.read_dbg_cnt_notify(reg_dbg_cnt_notify);
        cnt = reg_dbg_cnt_notify;
    endtask

    task clear_debug_counts();
        state_aging_core_reg_pkg::reg_dbg_control_t reg_dbg_control;
        this.read_dbg_control(reg_dbg_control);
        reg_dbg_control.clear_counts = 1'b1;
        this.write_dbg_control(reg_dbg_control);
        reg_dbg_control.clear_counts = 1'b0;
        this.write_dbg_control(reg_dbg_control);
    endtask

endclass : state_aging_core_reg_agent
