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

class raw_driver #(
    parameter type DATA_T = bit[15:0]
) extends driver#(raw_transaction#(DATA_T));

    //===================================
    // Properties
    //===================================
    virtual std_raw_intf #(DATA_T) raw_vif;

    local tx_mode_t __tx_mode = TX_MODE_SEND;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_driver");
        super.new(name);
    endfunction

    function automatic void set_tx_mode(input tx_mode_t tx_mode);
        this.__tx_mode = tx_mode;
    endfunction

    // Reset driver state
    // [[ implements _reset() virtual method of std_verif_pkg::driver parent class ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put (driven) stats update interface in idle state
    // [[ implements idle() virtual method of std_verif_pkg::driver parent class ]]
    task idle();
        raw_vif.idle_tx();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements _wait() virtual method of std_verif_pkg::driver parent class ]]
    task _wait(input int cycles);
        raw_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements wait_ready() virtual method of std_verif_pkg::driver parent class ]]
    task wait_ready();
        raw_vif.wait_ready();
    endtask

    task send_raw(DATA_T data);
        // Send transaction to interface
        case(this.__tx_mode)
            TX_MODE_SEND:            raw_vif.send(data);
            TX_MODE_PUSH:            raw_vif.push(data);
            TX_MODE_PUSH_WHEN_READY: raw_vif.push_when_ready(data);
            default:                 raw_vif.send(data);
        endcase
    endtask

    // Send raw transaction
    // [[ implements _send() virtual method of std_verif_pkg::driver parent class ]]
    task _send(input TRANSACTION_T transaction);
        info_msg($sformatf("Sending transaction '%s'", transaction.get_name()));
        debug_msg($sformatf("\n%s", transaction.to_string));
        send_raw(transaction.data);
    endtask

endclass : raw_driver
