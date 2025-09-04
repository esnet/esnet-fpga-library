virtual class packet_monitor#(
    parameter type META_T = bit
) extends std_verif_pkg::monitor#(packet#(META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_monitor";

    //===================================
    // Properties
    //===================================
    local int __MAX_PKT_SIZE = 65536;

    //===================================
    // Pure Virtual Methods
    // (to be implemented by derived class)
    //===================================
    pure protected virtual task _receive_raw(output byte data[], output META_T meta, output bit err);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="packet_monitor");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.__MAX_PKT_SIZE = 65536;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set/get receive packet size limit
    // (Used as upper bound on number of bytes received in a given transaction
    //  before the simulation is terminated (with $fatal).
    //  Guards against unbounded memory allocation due to protocol errors
    //  during simulation.)
    function void set_max_pkt_size(input int MAX_PKT_SIZE);
        this.__MAX_PKT_SIZE = MAX_PKT_SIZE;
    endfunction

    function int get_max_pkt_size();
        return this.__MAX_PKT_SIZE;
    endfunction

    // Receive packet transaction from packet interface
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    protected task _receive(output packet#(META_T) transaction);
        // Signals
        byte data [];
        bit err;
        META_T meta;

        packet_verif_pkg::packet_raw packet;

        debug_msg("Waiting for transaction...");

        // Receive transaction
        _receive_raw(data, meta, err);

        // Build Rx packet transaction
        transaction = packet_verif_pkg::packet_raw#(META_T)::create_from_bytes("rx_packet", data, meta, err);

        debug_msg($sformatf("Received %s (%0d bytes).", transaction.get_name(), transaction.size()));
    endtask

endclass
