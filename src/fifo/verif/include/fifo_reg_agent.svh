class fifo_reg_agent extends std_verif_pkg::agent;

    //===================================
    // Properties
    //===================================
    fifo_ctrl_reg_blk_agent   ctrl_reg_blk_agent;
    fifo_wr_mon_reg_blk_agent wr_mon_reg_blk_agent;
    fifo_rd_mon_reg_blk_agent rd_mon_reg_blk_agent;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="fifo_ctrl_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        ctrl_reg_blk_agent   = new("ctrl",   BASE_OFFSET);
        ctrl_reg_blk_agent.reg_agent = reg_agent;
        wr_mon_reg_blk_agent = new("wr_mon", BASE_OFFSET + 'h40);
        wr_mon_reg_blk_agent.reg_agent = reg_agent;
        rd_mon_reg_blk_agent = new("rd_mon", BASE_OFFSET + 'h80);
        rd_mon_reg_blk_agent.reg_agent = reg_agent;
    endfunction
 
    // Reset agent state
    // [[ overrides std_verif_pkg::agent._reset() virtual method ]]
    protected virtual function automatic void _reset();
        ctrl_reg_blk_agent.reset();
        wr_mon_reg_blk_agent.reset();
        rd_mon_reg_blk_agent.reset();
    endfunction

    // Put all (driven) interfaces into idle state
    // [[ overrides std_verif_pkg::agent._idle ]]
    virtual protected task _idle();
        ctrl_reg_blk_agent.idle();
    endtask

    task get_depth(output int depth);
        fifo_ctrl_reg_pkg::reg_info_depth_t reg_info_depth;
        this.ctrl_reg_blk_agent.read_info_depth(reg_info_depth);
        depth = reg_info_depth;
    endtask

    task get_width(output int width);
        fifo_ctrl_reg_pkg::reg_info_width_t reg_info_width;
        this.ctrl_reg_blk_agent.read_info_width(reg_info_width);
        width = reg_info_width;
    endtask

    task is_async(output bit async);
        fifo_ctrl_reg_pkg::reg_info_t reg_info;
        this.ctrl_reg_blk_agent.read_info(reg_info);
        if (reg_info.fifo_type === fifo_ctrl_reg_pkg::INFO_FIFO_TYPE_ASYNC) async = 1'b1;
        else                                                                async = 1'b0;
    endtask

    task get_wr_ptr(output int ptr);
        fifo_wr_mon_reg_pkg::reg_status_wr_ptr_t reg_status_wr_ptr;
        this.wr_mon_reg_blk_agent.read_status_wr_ptr(reg_status_wr_ptr);
        ptr = int'(reg_status_wr_ptr);
    endtask

    task get_wr_count(output int cnt);
        fifo_wr_mon_reg_pkg::reg_status_count_t reg_status_count;
        this.wr_mon_reg_blk_agent.read_status_count(reg_status_count);
        cnt = int'(reg_status_count);
    endtask

    task is_full(output bit full);
        fifo_wr_mon_reg_pkg::reg_status_t reg_status;
        this.wr_mon_reg_blk_agent.read_status(reg_status);
        full = reg_status.full;
    endtask

    task get_rd_ptr(output int ptr);
        fifo_rd_mon_reg_pkg::reg_status_rd_ptr_t reg_status_rd_ptr;
        this.rd_mon_reg_blk_agent.read_status_rd_ptr(reg_status_rd_ptr);
        ptr = int'(reg_status_rd_ptr);
    endtask

    task get_rd_count(output int cnt);
        fifo_rd_mon_reg_pkg::reg_status_count_t reg_status_count;
        this.rd_mon_reg_blk_agent.read_status_count(reg_status_count);
        cnt = int'(reg_status_count);
    endtask

    task is_empty(output bit empty);
        fifo_rd_mon_reg_pkg::reg_status_t reg_status;
        this.rd_mon_reg_blk_agent.read_status(reg_status);
        empty = reg_status.empty;
    endtask

    task soft_reset();
        fifo_ctrl_reg_pkg::reg_control_t reg_control;
        this.ctrl_reg_blk_agent.read_control(reg_control);
        reg_control.reset = 1'b1;
        this.ctrl_reg_blk_agent.write_control(reg_control);
        reg_control.reset = 1'b0;
        this.ctrl_reg_blk_agent.write_control(reg_control);
    endtask

endclass : fifo_reg_agent
