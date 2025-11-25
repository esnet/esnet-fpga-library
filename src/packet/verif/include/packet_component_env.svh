// Packet component testbench environment base class
class packet_component_env #(
    parameter type META_T = bit
) extends std_verif_pkg::component_env#(
    packet#(META_T),
    packet#(META_T),
    packet_driver#(META_T),
    packet_monitor#(META_T),
    std_verif_pkg::model#(packet#(META_T)),
    std_verif_pkg::scoreboard#(packet#(META_T))
);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_component_env";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="packet_component_env",
            packet_driver#(META_T) driver,
            packet_monitor#(META_T) monitor,
            std_verif_pkg::model#(packet#(META_T)) model,
            std_verif_pkg::scoreboard#(packet#(META_T)) scoreboard
        );
        super.new(name);
        this.driver = driver;
        this.monitor = monitor;
        this.model = model;
        this.scoreboard = scoreboard;
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

endclass : packet_component_env
