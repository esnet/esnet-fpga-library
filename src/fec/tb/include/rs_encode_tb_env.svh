import fec_pkg::*;
import fec_verif_pkg::*;

class rs_encode_tb_env #(
    parameter int  NUM_THREADS = 2,   // # threads = # symbols per data unit e.g. 2 symbols per byte.
    parameter type DATA_IN_T  = logic [RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0],
    parameter type DATA_OUT_T = logic [RS_N-1:0][NUM_THREADS*SYM_SIZE-1:0]
) extends std_verif_pkg::component_env#(
    std_verif_pkg::raw_transaction#(DATA_IN_T),
    std_verif_pkg::raw_transaction#(DATA_OUT_T),
    bus_verif_pkg::bus_driver#(DATA_IN_T),
    bus_verif_pkg::bus_monitor#(DATA_OUT_T),
    rs_model#(NUM_THREADS, raw_transaction#(DATA_IN_T), raw_transaction#(DATA_OUT_T)),
    std_verif_pkg::raw_scoreboard#(DATA_OUT_T)
);

    //===================================
    // Properties
    //===================================
    localparam int DATA_IN_WID  = $bits(DATA_IN_T);
    localparam int DATA_OUT_WID = $bits(DATA_OUT_T);

    //===================================
    // Properties
    //===================================
    virtual bus_intf #(DATA_IN_WID)  wr_vif;
    virtual bus_intf #(DATA_OUT_WID) rd_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            string name="rs_encode_tb_env",
            virtual std_reset_intf  _reset_vif,
            virtual bus_intf#(DATA_IN_WID)  _wr_vif,
            virtual bus_intf#(DATA_OUT_WID) _rd_vif
        );
        // Create superclass instance
        super.new(name);
        this.reset_vif = _reset_vif;
        
        // Create (raw data) testbench components
        this.driver = new();
        this.driver.bus_vif = _wr_vif;
        
        this.monitor = new();
        this.monitor.bus_vif = _rd_vif;

        this.model = new();
        this.scoreboard = new();
    endfunction

    task wait_n(input int cycles);
        wr_vif._wait(cycles);
    endtask

    automatic function void reset();
        trace_msg("reset()");
        super.reset();
        trace_msg("reset() Done.");
    endfunction

    virtual function automatic void destroy();
        super.destroy();
    endfunction

    function automatic void trace_msg(input string msg);
        _trace_msg(msg, "rs_encode_tb_env");
    endfunction

endclass
