// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

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

        reset();
    endfunction

    automatic function void reset_driver_mode();
        this.driver.set_tx_mode(std_verif_pkg::TX_MODE_PUSH_WHEN_READY);
    endfunction

    automatic function void reset_monitor_mode();
        if (FWFT) this.monitor.set_rx_mode(std_verif_pkg::RX_MODE_ACK);
        else      this.monitor.set_rx_mode(std_verif_pkg::RX_MODE_ACK_FETCH);
    endfunction

    automatic function void reset();
        super.reset();
        reset_driver_mode();
        reset_monitor_mode();
    endfunction

endclass
