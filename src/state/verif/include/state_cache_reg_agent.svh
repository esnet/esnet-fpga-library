class state_cache_reg_agent#(type KEY_T = bit, type ID_T = bit) extends state_cache_reg_blk_agent;

    //===================================
    // Properties
    //===================================
    db_reg_agent #(KEY_T, ID_T) db_agent;
    htable_cuckoo_reg_agent cuckoo_agent;
    htable_fast_update_reg_agent fast_update_agent;
    state_allocator_reg_agent allocator_agent;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="state_cache_reg_agent",
            input int NUM_IDS,
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
        this.cuckoo_agent = new("cuckoo_agent", reg_agent, BASE_OFFSET + 'h100);
        this.fast_update_agent = new("cuckoo_agent", reg_agent, BASE_OFFSET + 'h180);
        this.allocator_agent = new("allocator_agent", reg_agent, BASE_OFFSET + 'h200);
        this.db_agent = new("db_agent", NUM_IDS, reg_agent, BASE_OFFSET + 'h400);
        this.db_agent.set_reset_timeout(4*NUM_IDS);
        this.db_agent.set_op_timeout(128);
        reset();
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent._reset() virtual method ]]
    protected virtual function automatic void _reset();
        super._reset();
        db_agent.reset();
        cuckoo_agent.reset();
        fast_update_agent.reset();
        allocator_agent.reset();
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        soft_reset();
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        state_cache_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task soft_reset();
        state_cache_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    task get_size(output int size);
        state_cache_reg_pkg::reg_info_size_t reg_info_size;
        this.read_info_size(reg_info_size);
        size = reg_info_size;
    endtask

    task latch_counts(input bit clear = 1'b0);
        state_cache_reg_pkg::reg_cnt_control_t reg_cnt_control;
        reg_cnt_control._clear = clear;
        this.write_cnt_control(reg_cnt_control);
    endtask

    task get_req_cnt(output bit[63:0] cnt);
        this.read_cnt_req_upper(cnt[63:32]);
        this.read_cnt_req_lower(cnt[31:0]);
    endtask

    task get_tracked_existing_cnt(output bit[63:0] cnt);
        this.read_cnt_tracked_existing_upper(cnt[63:32]);
        this.read_cnt_tracked_existing_lower(cnt[31:0]);
    endtask

    task get_tracked_new_cnt(output bit[63:0] cnt);
        this.read_cnt_tracked_new_upper(cnt[63:32]);
        this.read_cnt_tracked_new_lower(cnt[31:0]);
    endtask

    task get_not_tracked_cnt(output bit[63:0] cnt);
        this.read_cnt_not_tracked_upper(cnt[63:32]);
        this.read_cnt_not_tracked_lower(cnt[31:0]);
    endtask

endclass : state_cache_reg_agent
