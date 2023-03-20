class tb_env #(
    parameter type DATA_T = bit[15:0],
    parameter bit FWFT = 1'b0
) extends std_verif_pkg::wire_env#(
    raw_transaction#(DATA_T),
    raw_driver#(DATA_T),
    raw_monitor#(DATA_T),
    raw_scoreboard#(DATA_T)
);

    //===================================
    // Properties
    //===================================
    virtual std_raw_intf #(DATA_T) wr_vif;
    virtual std_raw_intf #(DATA_T) rd_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            string name="tb_env",
            virtual std_reset_intf _reset_vif,
            virtual std_raw_intf#(DATA_T) _wr_vif,
            virtual std_raw_intf#(DATA_T) _rd_vif
        );
        // Create superclass instance
        super.new(name);
        this.reset_vif = _reset_vif;
        
        // Create (raw data) testbench components
        this.driver = new();
        this.driver.raw_vif = _wr_vif;
        
        this.monitor = new();
        this.monitor.raw_vif = _rd_vif;

        this.scoreboard = new();
    endfunction

    automatic function void reset_driver_mode();
        this.driver.set_tx_mode(std_verif_pkg::TX_MODE_PUSH_WHEN_READY);
    endfunction

    automatic function void reset_monitor_mode();
        if (FWFT) this.monitor.set_rx_mode(std_verif_pkg::RX_MODE_ACK);
        else      this.monitor.set_rx_mode(std_verif_pkg::RX_MODE_FETCH_VAL);
    endfunction

    automatic function void reset();
        trace_msg("reset()");
        super.reset();
        reset_driver_mode();
        reset_monitor_mode();
        trace_msg("reset() Done.");
    endfunction

endclass
