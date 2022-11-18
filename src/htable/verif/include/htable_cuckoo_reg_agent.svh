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

class htable_cuckoo_reg_agent extends htable_cuckoo_reg_blk_agent;

    //===================================
    // Properties
    //===================================
    
    //===================================
    // Methods
    //===================================
    function new(
            input string name="htable_cuckoo_reg_agent",
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
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        soft_reset();
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        htable_cuckoo_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task soft_reset();
        htable_cuckoo_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    task get_num_tables(output int num_tables);
        htable_cuckoo_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        num_tables = reg_info.num_tables;
    endtask

    task get_key_width(output int key_width);
        htable_cuckoo_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        key_width = reg_info.key_width;
    endtask

    task get_value_width(output int value_width);
        htable_cuckoo_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        value_width = reg_info.value_width;
    endtask

    task latch_counts(input bit clear = 1'b0);
        htable_cuckoo_reg_pkg::reg_cnt_control_t reg_cnt_control;
        reg_cnt_control._clear = clear;
        this.write_cnt_control(reg_cnt_control);
    endtask

    task get_insert_ok_cnt(output bit[63:0] cnt);
        this.read_cnt_insert_ok_upper(cnt[63:32]);
        this.read_cnt_insert_ok_lower(cnt[31:0]);
    endtask

    task get_insert_fail_cnt(output bit[63:0] cnt);
        this.read_cnt_insert_fail_upper(cnt[63:32]);
        this.read_cnt_insert_fail_lower(cnt[31:0]);
    endtask

    task get_delete_ok_cnt(output bit[63:0] cnt);
        this.read_cnt_delete_ok_upper(cnt[63:32]);
        this.read_cnt_delete_ok_lower(cnt[31:0]);
    endtask

    task get_delete_fail_cnt(output bit[63:0] cnt);
        this.read_cnt_delete_fail_upper(cnt[63:32]);
        this.read_cnt_delete_fail_lower(cnt[31:0]);
    endtask

    task get_active_cnt(output int cnt);
        this.read_cnt_active(cnt);
    endtask

    task get_dbg_active_cnt(output int cnt);
        this.read_dbg_cnt_active(cnt);
    endtask

    task get_stats(output stats_t stats, input bit clear);
        latch_counts(clear);
        get_insert_ok_cnt(stats.insert_ok);
        get_insert_fail_cnt(stats.insert_fail);
        get_delete_ok_cnt(stats.delete_ok);
        get_delete_fail_cnt(stats.delete_fail);
        get_active_cnt(stats.active);
    endtask

endclass : htable_cuckoo_reg_agent
