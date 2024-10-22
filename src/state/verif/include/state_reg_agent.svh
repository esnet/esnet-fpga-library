class state_reg_agent#(type ID_T = bit, type STATE_T = bit) extends state_reg_blk_agent;

    local static const string __CLASS_NAME = "state_verif_pkg::state_reg_agent";

    //===================================
    // Parameters
    //===================================
    const int NUM_IDS = 2**$bits(ID_T);

    //===================================
    // Properties
    //===================================
    db_reg_agent #(ID_T, STATE_T) db;
    state_notify_reg_agent notify;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="state_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
        this.notify = new($sformatf("%s[notify]", name), reg_agent, BASE_OFFSET + 'h200);
        this.db = new($sformatf("%s[db]", name), NUM_IDS, reg_agent, BASE_OFFSET + 'h400);
        this.db.set_reset_timeout(4*NUM_IDS);
        this.db.set_op_timeout(128);
        reset();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent._reset() virtual method ]]
    protected virtual function automatic void _reset();
        super._reset();
        notify.reset();
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        soft_reset();
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        state_reg_pkg::reg_status_t reg_status;
        do
            this.read_status(reg_status);
        while (reg_status.reset_mon == 1'b1 || reg_status.ready_mon == 1'b0);
    endtask

    task soft_reset();
        state_reg_pkg::reg_control_t reg_control;
        this.read_control(reg_control);
        reg_control.reset = 1;
        this.write_control(reg_control);
        reg_control.reset = 0;
        this.write_control(reg_control);
        wait_ready();
    endtask

    task get_size(output int size);
        state_reg_pkg::reg_info_size_t reg_info_size;
        this.read_info_size(reg_info_size);
        size = reg_info_size;
    endtask

    task get_num_elements(output int num_elements);
        state_reg_pkg::reg_info_num_elements_t reg_info_num_elements;
        this.read_info_num_elements(reg_info_num_elements);
        num_elements = reg_info_num_elements;
    endtask

endclass : state_reg_agent
