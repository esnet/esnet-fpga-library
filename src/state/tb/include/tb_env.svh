class tb_env #(
    parameter type ID_T = logic[7:0],
    parameter type STATE_T = logic,
    parameter type UPDATE_T = logic
) extends std_verif_pkg::basic_env;

    // Parameters
    localparam int NUM_IDS = 2**$bits(ID_T);
    localparam int RESET_TIMEOUT = NUM_IDS*4; // In clk cycles

    //===================================
    // Properties
    //===================================
    virtual state_intf #(ID_T, STATE_T, UPDATE_T) ctrl_vif;
    virtual state_intf #(ID_T, STATE_T, UPDATE_T) update_vif;

    state_model#(ID_T, STATE_T, UPDATE_T) model;

    db_verif_pkg::db_agent#(ID_T, STATE_T) db_agent;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="tb_env");
        super.new(name);
        set_reset_timeout(RESET_TIMEOUT);
    endfunction

    task idle();
        db_agent.idle();
        update_vif.idle();
        ctrl_vif.idle();
    endtask

    task wait_n(input int num_cycles);
        update_vif._wait(num_cycles);
    endtask

endclass : tb_env
