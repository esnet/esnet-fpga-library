// Clocked verification access to state_check_intf.
class state_check_agent #(
    parameter type STATE_T = bit, MSG_T = bit
) extends std_verif_pkg::agent;

    // Interface binding
    localparam int STATE_WID = $bits(STATE_T);
    localparam int MSG_WID = $bits(MSG_T);
    virtual state_check_intf #(STATE_WID, MSG_WID) state_vif;

    function new(input string name="state_check_agent");
        super.new(name);
        this.state_vif = null;
    endfunction

    // Clock control and transaction helpers
    virtual protected task _idle();
        state_vif.cb.req <= 1'b0;
        state_vif.cb.state  <= 'x;
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(state_vif.cb);
    endtask

    task _send_req(input STATE_T _state);
        state_vif.cb.req <= 1'b1;
        state_vif.cb.state <= _state;
        @(state_vif.cb);
        state_vif.cb.req <= 1'b0;
        state_vif.cb.state <= 'x;
    endtask

    task check(
            input STATE_T _state,
            output bit                _active,
            output bit                _notify,
            output MSG_T _msg
        );
        _send_req(_state);
        @(state_vif.cb);
        wait(state_vif.cb.ack);
        _active = state_vif.cb.active;
        _notify = state_vif.cb.notify;
        _msg = state_vif.cb.msg;
    endtask

endclass : state_check_agent
