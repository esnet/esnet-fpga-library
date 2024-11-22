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

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        packet_descriptor_vif = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Put (driven) packet interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        packet_descriptor_vif.idle_tx();
    endtask

    // Send packet descriptor transaction on packet descriptor interface
    // [[ implements std_verif_pkg::driver._send() ]]
    protected task _send(
            input packet_descriptor#(ADDR_T,META_T) transaction
        );

        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send transaction
        packet_descriptor_vif.send(transaction.get_addr(), transaction.get_size(), transaction.get_meta(), transaction.is_errored());

        debug_msg("Done.");
    endtask

endclass : packet_descriptor_driver
