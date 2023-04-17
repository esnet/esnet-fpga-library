class state_monitor #(
    parameter type ID_T = bit,
    parameter type STATE_T = bit,
    parameter type UPDATE_T = bit
) extends std_verif_pkg::monitor#(state_resp#(ID_T,STATE_T));

    //===================================
    // Properties
    //===================================
    virtual state_intf #(ID_T, STATE_T, UPDATE_T) update_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="state_monitor");
        super.new(name);
    endfunction

    // Reset monitor state
    // [[ implements _reset() virtual method of std_verif_pkg::monitor parent class ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put (monitored) state update interface in idle state
    // [[ implements idle() virtual method of std_verif_pkg::monitor parent class ]]
    task idle();
        // Nothing to do
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements _wait() virtual method of std_verif_pkg::monitor parent class ]]
    task _wait(input int cycles);
        update_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements wait_ready() virtual method of std_verif_pkg::monitor parent class ]]
    task wait_ready();
        update_vif.wait_ready();
    endtask

    // Receive transaction from interface
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    task _receive(
            output state_resp#(ID_T, STATE_T) transaction
        );
        STATE_T rx_state;
        bit __timeout;
        static int __rx_count = 0;

        debug_msg("Waiting for transaction...");

        update_vif.receive(rx_state, __timeout);
        
        transaction = new($sformatf("state_resp[%0d]", __rx_count++), rx_state);

        debug_msg($sformatf("Received %s.\n%s", transaction.get_name(), transaction.to_string()));
    endtask

endclass : state_monitor
