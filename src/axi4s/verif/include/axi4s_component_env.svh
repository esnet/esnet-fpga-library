// AXI-S component testbench environment base class
class axi4s_component_env #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends std_verif_pkg::component_env#(
    axi4s_transaction#(TID_T, TDEST_T, TUSER_T),
    axi4s_transaction#(TID_T, TDEST_T, TUSER_T),
    axi4s_driver#(DATA_BYTE_WID,TID_T, TDEST_T, TUSER_T),
    axi4s_monitor#(DATA_BYTE_WID,TID_T, TDEST_T, TUSER_T),
    std_verif_pkg::model#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T)),
    std_verif_pkg::scoreboard#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T))
);

    local static const string __CLASS_NAME = "axi4s_verif_pkg::axi4s_component_env";

    //===================================
    // Properties
    //===================================
    virtual axi4s_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .TID_T(TID_T),
        .TDEST_T(TDEST_T),
        .TUSER_T(TUSER_T)
    ) axis_in_vif;

    virtual axi4s_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .TID_T(TID_T),
        .TDEST_T(TDEST_T),
        .TUSER_T(TUSER_T)
    ) axis_out_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="axi4s_component_env",
            std_verif_pkg::model#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T)) model,
            std_verif_pkg::scoreboard#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T)) scoreboard,
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

    // Build and connect environment object
    // [[ overrides std_verif_pkg::component_env._build() ]]
    virtual protected function automatic void _build();
        trace_msg("_build()");
        super._build();
        this.driver.axis_vif = axis_in_vif;
        this.monitor.axis_vif = axis_out_vif;
        trace_msg("_build() Done.");
    endfunction

endclass : axi4s_component_env
