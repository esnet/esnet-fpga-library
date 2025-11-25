class axi4s_capture_monitor #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends std_verif_pkg::monitor#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T));

    local static const string __CLASS_NAME = "axi4s_verif_pkg::axi4s_capture_monitor";

    //===================================
    // Parameters
    //===================================
    localparam type META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;};

    //===================================
    // Properties
    //===================================
    packet_verif_pkg::packet_capture_monitor#(META_T) agent;

    //===================================
    // Methods
    //===================================
    function new(input string name="axi4s_capture_monitor",
                 input int mem_size=16384,
                 reg_verif_pkg::reg_agent reg_agent,
                 input int BASE_OFFSET=0
        );
        super.new(name);
        agent = new("packet_capture_monitor", mem_size, DATA_BYTE_WID*8, reg_agent, BASE_OFFSET);
        agent.outbox = new();
        agent.disable_autostart();
        register_subcomponent(agent);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Put (monitored) AXI-S interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        agent.idle();
    endtask

    task enable();
        agent.enable();
    endtask

    task _disable();
        agent._disable();
    endtask

    // Wait for interface to be ready to accept transactions
    task wait_ready();
        agent.wait_ready();
    endtask

    // Receive AXI-S transaction from AXI-S bus
    // [[ implements std_verif_pkg::monitor._receive() ]]
    task _receive(output axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction);
        packet_verif_pkg::packet#(META_T) packet;
        META_T meta;
        debug_msg("Waiting for transaction...");
        agent.receive(packet);
        meta = packet.get_meta();
        transaction = axi4s_transaction#(TID_T, TDEST_T, TUSER_T)::create_from_bytes(
            "rx_axi4s_transaction",
            packet.to_bytes(),
            meta.tid,
            meta.tdest,
            meta.tuser
        );
        debug_msg($sformatf("Received %s (%0d bytes).", transaction.get_name(), transaction.size()));
    endtask

endclass: axi4s_capture_monitor
