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

class raw_monitor #(
    parameter type DATA_T = bit[15:0]
) extends monitor#(raw_transaction#(DATA_T));

    //===================================
    // Properties
    //===================================
    virtual std_raw_intf #(DATA_T) raw_vif;

    local rx_mode_t __rx_mode = RX_MODE_RECEIVE;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_monitor");
        super.new(name);
    endfunction

    function automatic void set_rx_mode(input rx_mode_t rx_mode);
        this.__rx_mode = rx_mode;
    endfunction

    // Reset monitor state
    // [[ implements _reset() virtual method of std_verif_pkg::monitor parent class ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put monitor interface in idle state
    // [[ implements idle() virtual method of std_verif_pkg::monitor parent class ]]
    task idle();
        raw_vif.idle_rx;
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements _wait() virtual method of std_verif_pkg::monitor parent class ]]
    task _wait(input int cycles);
        raw_vif._wait(cycles);
    endtask

    task receive_raw(output DATA_T data);
        // Receive transaction from interface
        case (this.__rx_mode)
            RX_MODE_RECEIVE   : raw_vif.receive(data);
            RX_MODE_PULL      : raw_vif.pull(data);
            RX_MODE_ACK       : raw_vif.ack(data);
            RX_MODE_FETCH     : raw_vif.fetch(data);
            RX_MODE_ACK_FETCH : raw_vif.ack_fetch(data);
        endcase
    endtask

    // Receive raw transaction
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    task _receive(output TRANSACTION_T transaction);
        DATA_T rx_data;

        debug_msg("Waiting for transaction...");

        receive_raw(rx_data);

        transaction = new(
            $sformatf("raw_transaction[%d]", num_transactions()),
            rx_data
        );

        info_msg($sformatf("Received %s.\n%s", transaction.get_name(), transaction.to_string()));
    endtask

endclass : raw_monitor
