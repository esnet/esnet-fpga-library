class packet_descriptor_monitor #(
    parameter type ADDR_T = bit,
    parameter type META_T = bit
) extends std_verif_pkg::monitor#(packet_descriptor#(ADDR_T,META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_descriptor_monitor";

    local int __id = 0;

    //===================================
    // Interfaces
    //===================================
    virtual packet_descriptor_intf #(
        .ADDR_T(ADDR_T),
        .META_T(META_T)
    ) packet_descriptor_vif;

    //===================================
    // Typedefs
    //===================================
    // Constructor
    function new(input string name="packet_descriptor_monitor");
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
        this.__id = 0;
    endfunction

    // Put packet monitor interface in idle state
    // [[ implements std_verif_pkg::monitor.idle() ]]
    task idle();
        trace_msg("idle()");
        packet_descriptor_vif.idle_rx();
        trace_msg("idle() Done.");
    endtask

    // Wait for specified number of 'cycles' on the monitored interface
    // [[ implements std_verif_pkg::monitor._wait() ]]
    task _wait(input int cycles);
        packet_descriptor_vif._wait(cycles);
    endtask

    // Receive packet descriptor transaction from packet descriptor interface
    // [[ implements std_verif_pkg::monitor._receive() ]]
    task _receive(
            output packet_descriptor#(ADDR_T,META_T) transaction
        );
        // Signals
        ADDR_T addr;
        int size;
        META_T meta;

        trace_msg("_receive()");

        debug_msg("Waiting for transaction...");

        // Receive transaction
        packet_descriptor_vif.receive(addr, size, meta);

        // Build Rx packet descriptor transaction
        transaction = new($sformatf("rx_packet_descriptor[%0d]", this.__id), addr, size, meta);

        this.__id++;

        debug_msg(
            $sformatf("Received %s (addr: 0x%0x, %0d bytes, meta: 0x%0x)",
                transaction.get_name(),
                transaction.get_addr(),
                transaction.get_size(),
                transaction.get_meta()
            )
        );
        trace_msg("_receive() Done.");
    endtask

    task flush();
        packet_descriptor_vif.flush();
    endtask

endclass
