// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

// AXI-S component testbench environment base class
class axi4s_component_env #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends std_verif_pkg::component_env#(
    axi4s_transaction#(TID_T,TDEST_T,TUSER_T),
    axi4s_transaction#(TID_T,TDEST_T,TUSER_T),
    axi4s_driver#(DATA_BYTE_WID,TID_T,TDEST_T,TUSER_T),
    axi4s_monitor#(DATA_BYTE_WID,TID_T,TDEST_T,TUSER_T),
    std_verif_pkg::model#(axi4s_transaction#(TID_T,TDEST_T,TUSER_T)),
    std_verif_pkg::scoreboard#(axi4s_transaction#(TID_T,TDEST_T,TUSER_T))
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
            const ref std_verif_pkg::model#(axi4s_transaction#(TID_T,TDEST_T,TUSER_T)) model,
            const ref std_verif_pkg::scoreboard#(axi4s_transaction#(TID_T,TDEST_T,TUSER_T)) scoreboard,
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
        this.driver.axis_vif = axis_in_vif;
        this.monitor.axis_vif = axis_out_vif;
        trace_msg("connect() Done.");
    endfunction

endclass : axi4s_component_env
