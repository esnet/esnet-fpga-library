virtual class packet_monitor #(
    parameter type META_T = bit
) extends std_verif_pkg::monitor#(packet#(META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_monitor";

    // Constructor
    function new(input string name="packet_monitor");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Receive packet transaction from packet interface
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    task _receive(
            output packet#(META_T) transaction
        );
        // Signals
        byte data [];
        bit err;
        META_T meta;

        packet_verif_pkg::packet_raw packet;

        debug_msg("Waiting for transaction...");

        // Receive transaction
        receive_raw(data, meta, err);

        // Build Rx packet transaction
        transaction = packet_verif_pkg::packet_raw#(META_T)::create_from_bytes("rx_packet", data, meta, err);

        debug_msg($sformatf("Received %s (%0d bytes).", transaction.get_name(), transaction.size()));
    endtask

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    virtual task receive_raw(output byte data[], output META_T meta, output bit err); endtask

endclass
