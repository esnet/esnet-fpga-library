class tb_env #(
    parameter type ID_T = logic[7:0],
    parameter type STATE_T = logic,
    parameter type UPDATE_T = logic
) extends std_verif_pkg::basic_env;

    // Parameters
    localparam int NUM_IDS = 2**$bits(ID_T);
    localparam int RESET_TIMEOUT = NUM_IDS*4; // In clk cycles

    localparam int ID_WID = $bits(ID_T);
    localparam int STATE_WID = $bits(STATE_T);
    localparam int UPDATE_WID = $bits(UPDATE_T);

    //===================================
    // Properties
    //===================================
    state_intf_agent #(ID_T, STATE_T, UPDATE_T) ctrl_agent;
    state_intf_agent #(ID_T, STATE_T, UPDATE_T) update_agent;

    state_model#(ID_T, STATE_T, UPDATE_T) model;

    db_verif_pkg::db_agent#(ID_T, STATE_T) db_agent;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="tb_env");
        super.new(name);
        set_reset_timeout(RESET_TIMEOUT);
        ctrl_agent = new("ctrl_agent");
        update_agent = new("update_agent");
    endfunction

    task idle();
        db_agent.idle();
        update_agent.idle();
        ctrl_agent.idle();
    endtask

    task wait_n(input int num_cycles);
        update_agent.wait_n(num_cycles);
    endtask

endclass : tb_env
