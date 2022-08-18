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

class db_monitor #(
    parameter type KEY_T = bit[15:0],
    parameter type VALUE_T = bit[31:0]
) extends std_verif_pkg::monitor#(db_resp_transaction#(KEY_T, VALUE_T));

    local static const string __CLASS_NAME = "db_verif_pkg::db_monitor";

    //===================================
    // Properties
    //===================================
    virtual db_intf #(KEY_T, VALUE_T) db_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="db_monitor");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset monitor state
    // [[ implements _reset() virtual method of std_verif_pkg::monitor parent class ]]
    function automatic void _reset();
        trace_msg("_reset()");
        // Nothing to do
        trace_msg("_reset() Done.");
    endfunction

    // Put monitor interface in idle state
    // [[ implements idle() virtual method of std_verif_pkg::monitor parent class ]]
    task idle();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements _wait() virtual method of std_verif_pkg::monitor parent class ]]
    task _wait(input int cycles);
        db_vif._wait(cycles);
    endtask

    // Receive transaction (represented as raw byte array with associated metadata)
    task receive_raw(
            output bit found,
            output VALUE_T value
        );
        bit error;
        bit xid;
        trace_msg("receive_raw()");
        // Receive transaction from interface
        db_vif.receive(found, value, error, xid);
        trace_msg("receive_raw() Done.");
    endtask

    // Receive database transaction
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    task _receive(output db_resp_transaction transaction);
        bit found;
        VALUE_T value;

        trace_msg("_receive()");
        debug_msg("Waiting for transaction...");

        receive_raw(found, value);

        transaction = new(
            $sformatf("db_resp_transaction[%0d]", num_transactions()),
            0,
            found,
            value
        );

        debug_msg($sformatf("Received %s.\n%s", transaction.get_name(), transaction.to_string()));
        trace_msg("_receive() Done.");
    endtask

endclass
