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

class db_ctrl_agent #(
    parameter type KEY_T = bit[7:0],
    parameter type VALUE_T = bit[31:0]
) extends db_agent#(KEY_T, VALUE_T);

    local static const string __CLASS_NAME = "db_verif_pkg::db_ctrl_agent";

    //===================================
    // Properties
    //===================================
    // Control interface
    virtual db_ctrl_intf #(KEY_T, VALUE_T) ctrl_vif;

    // Info interface
    virtual db_info_intf info_vif;

    // Status interface
    virtual db_status_intf status_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="db_ctrl_agent",
            input int _size=1024
        );
        super.new(name, _size);
        this.set_reset_timeout(32+2*_size);
        this.set_op_timeout(32);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function automatic void attach(
            input virtual db_ctrl_intf#(KEY_T, VALUE_T) v_ctrl_if,
            input virtual db_status_intf v_status_if = null,
            input virtual db_info_intf v_info_if = null
        );
        attach_ctrl_if(v_ctrl_if);
        attach_status_if(v_status_if);
        attach_info_if(v_info_if);
    endfunction

    function automatic void attach_ctrl_if(virtual db_ctrl_intf#(KEY_T, VALUE_T) ctrl_if);
        this.ctrl_vif = ctrl_if;
    endfunction

    function automatic void attach_status_if(virtual db_status_intf status_if);
        this.status_vif = status_if;
    endfunction

    function automatic void attach_info_if(virtual db_info_intf info_if);
        this.info_vif = info_if;
    endfunction

    // Put all (driven) interfaces into idle state
    // [[ implements std_verif_pkg::agent.idle ]]
    task idle();
        ctrl_vif.idle();
    endtask

    // Wait for specified number of 'cycles', where a cycle is defined by
    // the reg_blk_agent (e.g. AXI-L aclk cycles for an AXI-L reg agent)
    // [[ implements std_verif_pkg::agent._wait ]]
    task _wait(input int cycles);
        ctrl_vif._wait(cycles);
    endtask

    // Wait for client init/reset to complete
    // [[ implements std_verif_pkg::agent.wait_ready ]]
    task wait_ready();
        bit timeout;
        ctrl_vif.wait_ready(timeout, this._RESET_TIMEOUT);
        assert (timeout == 0) else error_msg("TIMEOUT waiting for control interface.");
    endtask

    // Generic transaction (no timeout protection)
    // [[ implements db_agent::_transact ]]
    task _transact(input db_pkg::command_t _command, output bit _error);
        bit _timeout;
        trace_msg($sformatf("_transact(command=%s)", _command.name()));
        ctrl_vif.transact(_command, _error);
        trace_msg("_transact() Done.");
    endtask

    // Set key (for request)
    // [[ implements db_agent::_set_key ]]
    task _set_key(input KEY_T _key);
        trace_msg($sformatf("_set_key (key=0x%0x)", _key));
        ctrl_vif._set_key(_key);
        trace_msg("db_ctrl_agent._set_key() Done.");
    endtask

    // Set value (for request)
    // [[ implements db_agent::_set_value ]]
    task _set_value(input VALUE_T _value);
        trace_msg($sformatf("_set_value (value=0x%0x)", _value));
        ctrl_vif._set_value(_value);
        trace_msg("_set_value() Done.");
    endtask

    // Read valid (from response)
    // [[ implements db_agent::_get_valid ]]
    task _get_valid(output bit _valid);
        ctrl_vif._get_valid(_valid);
    endtask

    // Read key (from response)
    // [[ implements db_agent::_get_key ]]
    task _get_key(output KEY_T _key);
        ctrl_vif._get_key(_key);
    endtask
    // Read value (from response)
    // [[ implements db_agent::_get_value ]]
    task _get_value(output VALUE_T _value);
        ctrl_vif._get_value(_value);
    endtask

    // Get database type
    // [[ implements db_agent.get_type ]]
    task get_type(output db_pkg::type_t _type);
        _type = info_vif._type;
    endtask

    // Get database subtype
    // [[ implements db_agent.get_subtype ]]
    task get_subtype(output db_pkg::subtype_t _subtype);
        _subtype = info_vif.subtype;
    endtask

    // Get database size
    // [[ implements db_agent.get_size ]]
    task get_size(output int _size);
        _size = info_vif.size;
    endtask

    // Get database fill level
    // [[ implements db_agent.get_fill ]]
    task get_fill(output int _fill);
        _fill = status_vif.fill;
    endtask

    task get_activate_cnt(output int _cnt_activate);
        _cnt_activate = status_vif.cnt_activate;
    endtask

    task get_deactivate_cnt(output int _cnt_deactivate);
        _cnt_deactivate = status_vif.cnt_deactivate;
    endtask

endclass : db_ctrl_agent
