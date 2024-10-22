class packet_descriptor_driver #(
    parameter type ADDR_T = bit,
    parameter type META_T = bit
) extends std_verif_pkg::driver#(packet_descriptor#(ADDR_T,META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_descriptor_driver";

    //===================================
    // Interfaces
    //===================================
    virtual packet_descriptor_intf #(ADDR_T,META_T) packet_descriptor_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="packet_descriptor_driver");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset driver state
    // [[ implements std_verif_pkg::driver._reset() ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put (driven) packet interface in idle state
    // [[ implements std_verif_pkg::driver.idle() ]]
    task idle();
        packet_descriptor_vif.idle_tx();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements std_verif_pkg::driver._wait() ]]
    task _wait(input int cycles);
        packet_descriptor_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        bit timeout;
        packet_descriptor_vif.wait_ready(timeout, 0);
    endtask

    // Send packet descriptor transaction on packet descriptor interface
    // [[ implements std_verif_pkg::driver._send() ]]
    task _send(
            input packet_descriptor#(ADDR_T,META_T) transaction
        );

        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send transaction
        packet_descriptor_vif.send(transaction.get_addr(), transaction.get_size(), transaction.get_meta(), transaction.is_errored());

        debug_msg("Done.");
    endtask

endclass : packet_descriptor_driver
