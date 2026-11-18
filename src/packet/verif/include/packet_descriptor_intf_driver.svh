class packet_descriptor_intf_driver #(
    parameter type ADDR_T = bit,
    parameter type META_T = bit,
    parameter int MAX_PKT_SIZE = 16383
) extends std_verif_pkg::driver#(packet_descriptor#(ADDR_T,META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_descriptor_intf_driver";

    localparam int ADDR_WID = $bits(ADDR_T);
    localparam int META_WID = $bits(META_T);
    localparam int SIZE_WID = $clog2(MAX_PKT_SIZE+1);

    //===================================
    // Interfaces
    //===================================
    virtual packet_descriptor_intf #(.ADDR_WID(ADDR_WID), .META_WID(META_WID), .MAX_PKT_SIZE(MAX_PKT_SIZE)) packet_descriptor_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="packet_descriptor_intf_driver");
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
    // Put (driven) packet interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    protected task _idle();
        packet_descriptor_vif.cb_tx.vld   <= 1'b0;
        packet_descriptor_vif.cb_tx.addr  <= 'x;
        packet_descriptor_vif.cb_tx.size  <= 'x;
        packet_descriptor_vif.cb_tx.err   <= 1'bx;
        packet_descriptor_vif.cb_tx.meta  <= 'x;
        packet_descriptor_vif.cb_tx.cksum <= 'x;
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(packet_descriptor_vif.cb_tx);
    endtask

    task send_raw(
            input bit [ADDR_WID-1:0]                    _addr,
            input int                                   _size,
            input bit [META_WID-1:0]                    _meta  = '0,
            input bit                                   _err   = 1'b0,
            input bit [packet_pkg::CKSUM_FIELD_WID-1:0] _cksum = '0
        );
        packet_descriptor_vif.cb_tx.vld   <= 1'b1;
        packet_descriptor_vif.cb_tx.addr  <= _addr;
        packet_descriptor_vif.cb_tx.size  <= _size[SIZE_WID-1:0];
        packet_descriptor_vif.cb_tx.err   <= _err;
        packet_descriptor_vif.cb_tx.meta  <= _meta;
        packet_descriptor_vif.cb_tx.cksum <= _cksum;
        @(packet_descriptor_vif.cb_tx iff (packet_descriptor_vif.cb_tx.mon_tx_vld && packet_descriptor_vif.cb_tx.rdy));
        packet_descriptor_vif.cb_tx.vld  <= 1'b0;
    endtask

    task wait_ready(
            output bit _timeout,
            input  int TIMEOUT=0
        );
        bit timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        @(packet_descriptor_vif.cb_tx iff (packet_descriptor_vif.cb_tx.rdy));
                    end
                    begin
                        timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            wait_n(TIMEOUT);
                            timeout = 1'b1;
                        end else wait(0);
                    end
                join_any
                disable fork;
            end
        join
        _timeout = timeout;
    endtask

    //===================================
    // Transaction-object adapter
    //===================================
    // Send packet descriptor transaction on packet descriptor interface
    // [[ implements std_verif_pkg::driver._send() ]]
    protected task _send(input packet_descriptor#(ADDR_T,META_T) transaction);

        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send transaction
        send_raw(transaction.addr, transaction.size, transaction.meta, transaction.err, transaction.cksum);

        debug_msg("Done.");
    endtask

endclass : packet_descriptor_intf_driver
