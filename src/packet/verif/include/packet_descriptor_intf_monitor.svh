class packet_descriptor_intf_monitor #(
    parameter type ADDR_T = bit,
    parameter type META_T = bit,
    parameter int MAX_PKT_SIZE = 16383
) extends std_verif_pkg::monitor#(packet_descriptor#(ADDR_T,META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_descriptor_monitor";

    localparam int ADDR_WID = $bits(ADDR_T);
    localparam int META_WID = $bits(META_T);

    //===================================
    // Interfaces
    //===================================
    virtual packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) packet_descriptor_vif;

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

    //===================================
    // Clocking-block interface control and transfers
    //===================================
    // Put packet monitor interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    protected task _idle();
        packet_descriptor_vif.cb_rx.rdy <= 1'b0;
    endtask

    task flush();
        packet_descriptor_vif.cb_rx.rdy <= 1'b1;
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(packet_descriptor_vif.cb_rx);
    endtask

    task receive_raw(
            output bit [ADDR_WID-1:0]                    _addr,
            output int                                   _size,
            output bit [META_WID-1:0]                    _meta,
            output bit                                   _err,
            output bit [packet_pkg::CKSUM_FIELD_WID-1:0] _cksum
        );
        packet_descriptor_vif.cb_rx.rdy <= 1'b1;
        @(packet_descriptor_vif.cb_rx iff (packet_descriptor_vif.cb_rx.vld && packet_descriptor_vif.cb_rx.mon_rx_rdy));
        packet_descriptor_vif.cb_rx.rdy  <= 1'b0;
        _addr  = packet_descriptor_vif.cb_rx.addr;
        _size  = packet_descriptor_vif.cb_rx.size;
        _meta  = packet_descriptor_vif.cb_rx.meta;
        _err   = packet_descriptor_vif.cb_rx.err;
        _cksum = packet_descriptor_vif.cb_rx.cksum;
    endtask

    //===================================
    // Transaction-object adapter
    //===================================
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
        packet_pkg::cksum_t cksum;

        trace_msg("_receive()");

        debug_msg("Waiting for transaction...");

        // Receive transaction
        receive_raw(addr, size, meta, err, cksum);

        // Build Rx packet descriptor transaction
        transaction = new($sformatf("rx_packet_descriptor[%0d]", num_transactions()), addr, size, meta, err, cksum);

        debug_msg(
            $sformatf("Received %s (addr: 0x%0x, %0d bytes, err: %0b, meta: 0x%0x, cksum: 0x%04x)",
                transaction.get_name(),
                transaction.addr,
                transaction.size,
                transaction.err,
                transaction.meta,
                transaction.cksum
            )
        );
        trace_msg("_receive() Done.");
    endtask

endclass : packet_descriptor_intf_monitor
