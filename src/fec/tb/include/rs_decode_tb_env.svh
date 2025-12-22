import fec_pkg::*;
import fec_verif_pkg::*;

class rs_decode_tb_env #(
    parameter int  NUM_THREADS = 2,  // # threads = # symbols per data unit e.g. 2 symbols per byte.
    parameter type DATA_T = logic [RS_K-1:0][NUM_THREADS*SYM_SIZE-1:0]
) extends std_verif_pkg::component_env#(
    std_verif_pkg::raw_transaction#(DATA_T),
    std_verif_pkg::raw_transaction#(DATA_T),
    bus_verif_pkg::bus_driver#(DATA_T),
    bus_verif_pkg::bus_monitor#(DATA_T),
    wire_model#(raw_transaction#(DATA_T)),
    std_verif_pkg::raw_scoreboard#(DATA_T)
);

    //===================================
    // Properties
    //===================================
    localparam int DATA_WID = $bits(DATA_T);

    //===================================
    // Properties
    //===================================
    virtual bus_intf #(DATA_WID) wr_vif;
    virtual bus_intf #(DATA_WID) rd_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            string name="rs_decode_tb_env",
            virtual std_reset_intf _reset_vif,
            virtual bus_intf#(DATA_WID) _wr_vif,
            virtual bus_intf#(DATA_WID) _rd_vif
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
        _trace_msg(msg, "rs_decode_tb_env");
    endfunction

endclass
