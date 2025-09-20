class tb_env #(
    parameter type DATA_T = bit[15:0]
) extends wire_env#(
    raw_transaction#(DATA_T),
    bus_driver#(DATA_T),
    bus_monitor#(DATA_T),
    raw_scoreboard#(DATA_T)
);

    //===================================
    // Parameters
    //===================================
    localparam int DATA_WID = $bits(DATA_T);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            string name="tb_env",
            virtual std_reset_intf _reset_vif,
            virtual bus_intf#(DATA_WID) _in_vif,
            virtual bus_intf#(DATA_WID) _out_vif
        );
        // Create superclass instance
        super.new(name);
        this.reset_vif = _reset_vif;
        
        // Create (raw data) testbench components
        this.driver = new();
        this.driver.bus_vif = _in_vif;
        
        this.monitor = new();
        this.monitor.bus_vif = _out_vif;

        this.scoreboard = new();
    endfunction

    automatic function void reset_driver_mode();
        this.driver.set_tx_mode(bus_verif_pkg::TX_MODE_SEND);
    endfunction

    automatic function void reset_monitor_mode();
        this.monitor.set_rx_mode(bus_verif_pkg::RX_MODE_RECEIVE);
    endfunction

    automatic function void reset();
        trace_msg("reset()");
        super.reset();
        reset_driver_mode();
        reset_monitor_mode();
        trace_msg("reset() Done.");
    endfunction

endclass
