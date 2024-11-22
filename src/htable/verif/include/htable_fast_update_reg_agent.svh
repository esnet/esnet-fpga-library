class htable_fast_update_reg_agent extends htable_fast_update_reg_blk_agent;

    //===================================
    // Properties
    //===================================
    
    //===================================
    // Methods
    //===================================
    function new(
            input string name="htable_fast_update_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
    endfunction

    // Reset client
    task reset_client();
        soft_reset();
    endtask

    // Poll register block for ready status
    task wait_ready();
        htable_fast_update_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task soft_reset();
        htable_fast_update_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    task get_burst_size(output int burst_size);
        htable_fast_update_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        burst_size = reg_info.burst_size;
    endtask

    task get_key_width(output int key_width);
        htable_fast_update_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        key_width = reg_info.key_width;
    endtask

    task get_value_width(output int value_width);
        htable_fast_update_reg_pkg::reg_info_t reg_info;
        this.read_info(reg_info);
        value_width = reg_info.value_width;
    endtask

    task latch_counts(input bit clear = 1'b0);
        htable_fast_update_reg_pkg::reg_cnt_control_t reg_cnt_control;
        reg_cnt_control._clear = clear;
        this.write_cnt_control(reg_cnt_control);
    endtask

    task get_update_cnt(output bit [63:0] cnt);
        this.read_cnt_update_upper(cnt[63:32]);
        this.read_cnt_update_lower(cnt[31:0]);
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

endclass : htable_fast_update_reg_agent
