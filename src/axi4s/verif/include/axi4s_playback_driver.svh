class axi4s_playback_driver #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends std_verif_pkg::driver#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T));

    local static const string __CLASS_NAME = "axi4s_verif_pkg::axi4s_playback_driver";

    //===================================
    // Parameters
    //===================================
    localparam type META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;};

    //===================================
    // Properties
    //===================================
    packet_verif_pkg::packet_playback_driver#(META_T) agent;

    //===================================
    // Methods
    //===================================
    function new(input string name="axi4s_playback_driver",
                 input int mem_size=16384,
                 const ref reg_verif_pkg::reg_agent reg_agent,
                 input int BASE_OFFSET=0
        );
        super.new(name);
        agent = new("packet_playback_driver", mem_size, DATA_BYTE_WID*8, reg_agent, BASE_OFFSET);
        agent.inbox = new();
        agent.disable_autostart();
        register_subcomponent(agent);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Put (driven) AXI-S interface in idle state
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
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        agent.wait_ready();
    endtask

    // Send packet as raw byte array
    // [[ implements std_verif_pkg::driver._send ]]
    task _send(input axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction);
        packet_verif_pkg::packet_raw#(META_T) packet;
        META_T meta;
        trace_msg("_send()");
        meta.tid = transaction.get_tid();
        meta.tdest = transaction.get_tdest();
        meta.tuser = transaction.get_tuser();
        packet = packet_verif_pkg::packet_raw#(META_T)::create_from_bytes(
            "packet",
            transaction.to_bytes(),
            meta
        );
        agent.send(packet);
        trace_msg("_send() Done.");
    endtask

endclass: axi4s_playback_driver
