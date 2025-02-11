class sar_reassembly_htable_reg_agent#(type BUF_ID_T = bit, type OFFSET_T = bit, type FRAGMENT_PTR_T = bit) extends reg_verif_pkg::reg_blk_agent;

    //===================================
    // Typedefs
    //===================================
    typedef struct packed {BUF_ID_T buf_id; OFFSET_T offset;} __DB_KEY_T;
    typedef struct packed {FRAGMENT_PTR_T ptr; OFFSET_T offset;} __DB_VALUE_T;

    //===================================
    // Properties
    //===================================
    db_reg_agent #(__DB_KEY_T,__DB_VALUE_T) db;
    htable_cuckoo_reg_agent cuckoo;
    htable_fast_update_reg_agent fast_update;

    //===================================
    // Methods
    //===================================
    function new(
            input string name="sar_reassembly_htable_reg_agent",
            input int MAX_FRAGMENTS,
            const ref reg_verif_pkg::reg_agent reg_agent,
            input int BASE_OFFSET=0
    );
        super.new(name, BASE_OFFSET);
        this.reg_agent = reg_agent;
        this.cuckoo      = new("cuckoo_agent",            reg_agent, BASE_OFFSET + 'h100);
        this.fast_update = new("fast_update_agent",       reg_agent, BASE_OFFSET + 'h180);
        this.db          = new("db_agent", MAX_FRAGMENTS, reg_agent, BASE_OFFSET + 'h400);
        this.db.set_reset_timeout(4*MAX_FRAGMENTS);
        this.db.set_op_timeout(128);
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::agent.reset() virtual method ]]
    function automatic void reset();
        // Nothing to do
    endfunction

    // Reset client
    // [[ implements std_verif_pkg::agent.reset_client ]]
    task reset_client();
        // Nothing to do
    endtask

    // Poll register block for ready status
    // [[ implements std_verif_pkg::agent.wait_ready() virtual method ]]
    task wait_ready();
        this.db.wait_ready();
    endtask

endclass : sar_reassembly_htable_reg_agent
