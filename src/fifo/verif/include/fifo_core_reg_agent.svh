class fifo_ctrl_reg_agent extends std_verif_pkg::agent;

    //===================================
    // Properties
    //===================================
    fifo_ctrl_info_reg_blk_agent   info_reg_blk_agent;
    fifo_ctrl_wr_mon_reg_blk_agent wr_mon_reg_blk_agent;
    fifo_ctrl_rd_mon_reg_blk_agent rd_mon_reg_blk_agent;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="fifo_ctrl_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        info_reg_blk_agent   = new("info_agent",   BASE_OFFSET);
        info_reg_blk_agent.reg_agent = reg_agent;
        wr_mon_reg_blk_agent = new("wr_mon_agent", BASE_OFFSET + 'h40);
        wr_mon_reg_blk_agent.reg_agent = reg_agent;
        rd_mon_reg_blk_agent = new("rd_mon_agent", BASE_OFFSET + 'h80);
        rd_mon_reg_blk_agent.reg_agent = reg_agent;
    endfunction
 
    // Reset agent state
    // [[ implements std_verif_pkg::agent.reset() virtual method ]]
    function automatic void reset();
        // Nothing extra to do
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        // Nothing to do
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        info_reg_blk_agent.wait_ready();
    endtask

    // Put all (driven) interfaces into idle state
    // [[ implements std_verif_pkg::agent.idle ]]
    task idle();
        info_reg_blk_agent.idle();
    endtask

    // Wait for specified number of 'cycles', where the definition of 'cycle' is agent-specific
    // [[ implements std_verif_pkg::agent._wait ]]
    task _wait(input int cycles);
        info_reg_blk_agent._wait(cycles);
    endtask

    task get_depth(output int depth);
        fifo_ctrl_info_reg_pkg::reg_info_depth_t reg_info_depth;
        this.info_reg_blk_agent.read_info_depth(reg_info_depth);
        depth = reg_info_depth;
    endtask

    task is_async(output bit async);
        fifo_ctrl_info_reg_pkg::reg_info_t reg_info;
        this.info_reg_blk_agent.read_info(reg_info);
        if (reg_info.fifo_type === fifo_ctrl_info_reg_pkg::INFO_FIFO_TYPE_ASYNC) async = 1'b1;
        else                                                                     async = 1'b0;
    endtask

    task get_wr_ptr(output int ptr);
        fifo_ctrl_wr_mon_reg_pkg::reg_status_wr_ptr_t reg_status_wr_ptr;
        this.wr_mon_reg_blk_agent.read_status_wr_ptr(reg_status_wr_ptr);
        ptr = int'(reg_status_wr_ptr);
    endtask

    task get_wr_count(output int cnt);
        fifo_ctrl_wr_mon_reg_pkg::reg_status_count_t reg_status_count;
        this.wr_mon_reg_blk_agent.read_status_count(reg_status_count);
        cnt = int'(reg_status_count);
    endtask

    task is_full(output bit full);
        fifo_ctrl_wr_mon_reg_pkg::reg_status_t reg_status;
        this.wr_mon_reg_blk_agent.read_status(reg_status);
        full = reg_status.full;
    endtask

    task get_rd_ptr(output int ptr);
        fifo_ctrl_rd_mon_reg_pkg::reg_status_rd_ptr_t reg_status_rd_ptr;
        this.rd_mon_reg_blk_agent.read_status_rd_ptr(reg_status_rd_ptr);
        ptr = int'(reg_status_rd_ptr);
    endtask

    task get_rd_count(output int cnt);
        fifo_ctrl_rd_mon_reg_pkg::reg_status_count_t reg_status_count;
        this.rd_mon_reg_blk_agent.read_status_count(reg_status_count);
        cnt = int'(reg_status_count);
    endtask

    task is_empty(output bit empty);
        fifo_ctrl_rd_mon_reg_pkg::reg_status_t reg_status;
        this.rd_mon_reg_blk_agent.read_status(reg_status);
        empty = reg_status.empty;
    endtask



endclass : fifo_ctrl_reg_agent
