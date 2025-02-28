class alloc_reg_agent extends alloc_reg_blk_agent;
    //===================================
    // Typedefs
    //===================================
    typedef struct {bit alloc_err; bit dealloc_err;} flags_t;

    //===================================
    // Properties
    //===================================
    local flags_t __flags;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="alloc_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
        __clear_flags();
    endfunction
 
    // Reset agent state
    // [[ implements std_verif_pkg::agent._reset() virtual method ]]
    protected virtual function automatic void _reset();
        super._reset();
        __clear_flags();
    endfunction

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        alloc_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset == 1'b1 || reg_status.init_done == 1'b0);
    endtask

    task soft_reset();
        alloc_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    task get_size(output int size);
        alloc_reg_pkg::reg_info_size_t reg_info_size;
        this.read_info_size(reg_info_size);
        size = reg_info_size;
    endtask

    task get_active_cnt(output int cnt);
        alloc_reg_pkg::reg_cnt_active_t reg_cnt_active;
        this.read_cnt_active(reg_cnt_active);
        cnt = reg_cnt_active;
    endtask

    task get_alloc_cnt(output int cnt);
        alloc_reg_pkg::reg_dbg_cnt_alloc_t reg_dbg_cnt_alloc;
        this.read_dbg_cnt_alloc(reg_dbg_cnt_alloc);
        cnt = reg_dbg_cnt_alloc;
    endtask

    task get_alloc_err_cnt(output int cnt);
        alloc_reg_pkg::reg_dbg_cnt_alloc_err_t reg_dbg_cnt_alloc_err;
        this.read_dbg_cnt_alloc_err(reg_dbg_cnt_alloc_err);
        cnt = reg_dbg_cnt_alloc_err;
    endtask

    task get_dealloc_cnt(output int cnt);
        alloc_reg_pkg::reg_dbg_cnt_dealloc_t reg_dbg_cnt_dealloc;
        this.read_dbg_cnt_dealloc(reg_dbg_cnt_dealloc);
        cnt = reg_dbg_cnt_dealloc;
    endtask

    task get_dealloc_err_cnt(output int cnt);
        alloc_reg_pkg::reg_dbg_cnt_dealloc_err_t reg_dbg_cnt_dealloc_err;
        this.read_dbg_cnt_dealloc_err(reg_dbg_cnt_dealloc_err);
        cnt = reg_dbg_cnt_dealloc_err;
    endtask

    task enable_alloc();
        alloc_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.allocate_en = 1;
        this.write_control(reg_control);
    endtask

    task disable_alloc();
        alloc_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.allocate_en = 0;
        this.write_control(reg_control);
    endtask

    local function automatic void __clear_flags();
        this.__flags = '{default: 1'b0};
    endfunction

    // Read flags; store result in __flags for subsequent inspection
    task update_flags();
        alloc_reg_pkg::reg_status_flags_t reg_status_flags;
        this.read_status_flags(reg_status_flags);
        this.__flags.alloc_err = reg_status_flags.alloc_err;
        this.__flags.dealloc_err = reg_status_flags.dealloc_err;
        debug_msg(print_flags());
    endtask

    function automatic string print_flags();
        return $sformatf(
            "Flags [alloc_err: %b, dealloc_err: %b]",
            this.__flags.alloc_err,
            this.__flags.dealloc_err
        );
    endfunction

    function automatic bit is_alloc_err();
        return this.__flags.alloc_err;
    endfunction
    
    function automatic bit is_dealloc_err();
        return this.__flags.dealloc_err;
    endfunction

    task get_alloc_err_ptr(output int ptr);
        alloc_reg_pkg::reg_alloc_err_ptr_t reg_alloc_err_ptr;
        this.read_alloc_err_ptr(reg_alloc_err_ptr);
        ptr = reg_alloc_err_ptr;
    endtask

    task get_dealloc_err_ptr(output int ptr);
        alloc_reg_pkg::reg_dealloc_err_ptr_t reg_dealloc_err_ptr;
        this.read_dealloc_err_ptr(reg_dealloc_err_ptr);
        ptr = reg_dealloc_err_ptr;
    endtask


endclass : alloc_reg_agent
