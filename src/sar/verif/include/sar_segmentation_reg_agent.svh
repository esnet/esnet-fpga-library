class sar_segmentation_reg_agent extends sar_segmentation_reg_blk_agent;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="sar_segmentation_reg_agent",
            reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
        reset();
    endfunction

    function automatic void reset();
        super.reset();
    endfunction

    task reset_client();
        soft_reset();
    endtask

    task wait_ready();
        sar_segmentation_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task soft_reset();
        sar_segmentation_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    task clear_dbg_counts();
        sar_segmentation_reg_pkg::reg_dbg_control_t reg_dbg_control;
        reg_dbg_control.clear_counts = 1;
        this.write_dbg_control(reg_dbg_control);
    endtask

    task get_frames_in_cnt(output int cnt);
        sar_segmentation_reg_pkg::reg_dbg_cnt_frames_in_t reg_cnt;
        this.read_dbg_cnt_frames_in(reg_cnt);
        cnt = reg_cnt;
    endtask

    task get_segments_out_cnt(output int cnt);
        sar_segmentation_reg_pkg::reg_dbg_cnt_segments_out_t reg_cnt;
        this.read_dbg_cnt_segments_out(reg_cnt);
        cnt = reg_cnt;
    endtask

endclass : sar_segmentation_reg_agent
