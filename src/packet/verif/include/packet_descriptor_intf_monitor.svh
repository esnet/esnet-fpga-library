class packet_descriptor_intf_monitor #(
    parameter type ADDR_T = logic,
    parameter type META_T = logic
) extends std_verif_pkg::monitor#(packet_descriptor#(ADDR_T,META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_descriptor_monitor";

    //===================================
    // Interfaces
    //===================================
    virtual packet_descriptor_intf #(ADDR_T,META_T) packet_descriptor_vif;

    //===================================
    // Typedefs
    //===================================
    // Constructor
    function new(input string name="packet_descriptor_intf_monitor");
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

    // Put packet monitor interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        packet_descriptor_vif.idle_rx();
    endtask

    // Receive packet descriptor transaction from packet descriptor interface
    // [[ implements std_verif_pkg::monitor._receive() ]]
    protected task _receive(
            output packet_descriptor#(ADDR_T,META_T) transaction
        );
        // Signals
        ADDR_T addr;
        int size;
        META_T meta;
        bit err;

        trace_msg("_receive()");

        debug_msg("Waiting for transaction...");

        // Receive transaction
        packet_descriptor_vif.receive(addr, size, meta, err);

        // Build Rx packet descriptor transaction
        transaction = new($sformatf("rx_packet_descriptor[%0d]", num_transactions()), addr, size, meta, err);

        debug_msg(
            $sformatf("Received %s (addr: 0x%0x, %0d bytes, err: %0b, meta: 0x%0x)",
                transaction.get_name(),
                transaction.addr,
                transaction.size,
                transaction.err,
                transaction.meta
            )
        );
        trace_msg("_receive() Done.");
    endtask

    task flush();
        packet_descriptor_vif.flush();
    endtask

endclass : packet_descriptor_intf_monitor
