// Packet component testbench environment base class
class packet_component_env #(
    parameter int DATA_BYTE_WID = 8,
    parameter type META_T = bit
) extends std_verif_pkg::component_env#(
    packet#(META_T),
    packet#(META_T),
    packet_driver#(DATA_BYTE_WID,META_T),
    packet_monitor#(DATA_BYTE_WID,META_T),
    std_verif_pkg::model#(packet#(META_T)),
    std_verif_pkg::scoreboard#(packet#(META_T))
);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_component_env";

    //===================================
    // Properties
    //===================================
    virtual packet_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .META_T(META_T)
    ) packet_in_vif;

    virtual packet_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .META_T(META_T)
    ) packet_out_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="packet_component_env",
            const ref std_verif_pkg::model#(packet#(META_T)) model,
            const ref std_verif_pkg::scoreboard#(packet#(META_T)) scoreboard,
            input bit BIGENDIAN=1
        );
        super.new(name);
        this.driver = new(.BIGENDIAN(BIGENDIAN));
        this.monitor = new(.BIGENDIAN(BIGENDIAN));
        this.model = model;
        this.scoreboard = scoreboard;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Connect environment objects
    // [[ implements std_verif_pkg::component.connect() ]]
    function automatic void connect();
        trace_msg("connect()");
        super.connect();
        this.driver.packet_vif = packet_in_vif;
        this.monitor.packet_vif = packet_out_vif;
        trace_msg("connect() Done.");
    endfunction

endclass : packet_component_env
