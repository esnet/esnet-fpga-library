class sar_reassembly_state_reg_agent#(type BUF_ID_T = bit, type OFFSET_T = bit, type FRAGMENT_PTR_T = bit, type TIMER_T = bit) extends reg_verif_pkg::reg_blk_agent;

    //===================================
    // Typedefs
    //===================================
    typedef struct packed {
        bit valid;
        BUF_ID_T buf_id;
        OFFSET_T offset_start;
        OFFSET_T offset_end;
        TIMER_T timer;
        bit last;
    } STATE_T;

    //===================================
    // Properties
    //===================================
    state_reg_agent #(FRAGMENT_PTR_T, STATE_T) core;
    sar_reassembly_state_check_reg_agent check;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="sar_reassembly_state_reg_agent",
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.check = new("check_agent", reg_agent, BASE_OFFSET + 'h000);
        this.core = new("core_agent", reg_agent, BASE_OFFSET + 'h200);
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent.reset() virtual method ]]
    function automatic void reset();
        super.reset();
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        // Nothing to do
    endtask

endclass : sar_reassembly_state_reg_agent
