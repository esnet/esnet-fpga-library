// Clocked verification access to state_intf.
class state_intf_agent #(
    parameter type ID_T = bit, STATE_T = bit, UPDATE_T = bit
) extends std_verif_pkg::agent;

    // Interface binding
    localparam int ID_WID = $bits(ID_T);
    localparam int STATE_WID = $bits(STATE_T);
    localparam int UPDATE_WID = $bits(UPDATE_T);
    virtual state_intf #(ID_WID, STATE_WID, UPDATE_WID) state_vif;

    function new(input string name="state_intf_agent");
        super.new(name);
        this.state_vif = null;
    endfunction

    // Clock control and transaction helpers
    virtual protected task _idle();
        state_vif.cb.req    <= 1'b0;
        state_vif.cb.ctxt   <= UPDATE_CTXT_NOP;
        state_vif.cb.id     <=   'x;
        state_vif.cb.init   <= 1'bx;
        state_vif.cb.update <=   'x;
        @(state_vif.cb);
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(state_vif.cb);
    endtask

    task _req(
            input ID_T _id,
            input update_ctxt_t    _ctxt
        );
        state_vif.cb.req  <= 1'b1;
        state_vif.cb.id   <= _id;
        state_vif.cb.ctxt <= _ctxt;
        @(state_vif.cb iff (state_vif.cb.mon_req && state_vif.cb.rdy));
        state_vif.cb.req  <= 1'b0;
        state_vif.cb.id   <= 'x;
        state_vif.cb.ctxt <= UPDATE_CTXT_NOP;
    endtask

    // Bound acknowledgement waits without cancelling child processes.
    task _wait_ack(output bit _timeout, input int TIMEOUT=0);
        int cycles = 0;
        _timeout = 0;
        if (TIMEOUT <= 0) begin
            @(state_vif.cb iff (state_vif.cb.ack));
            return;
        end
        do begin
            @(state_vif.cb);
            cycles++;
            if (TIMEOUT > 0 && cycles >= TIMEOUT) begin
                _timeout = 1;
                return;
            end
        end while (!state_vif.cb.ack);
    endtask

    task nop_req(
            input ID_T _id = '0
        );
        _req(_id, UPDATE_CTXT_NOP);
    endtask

    task update_req(
            input ID_T     _id,
            input UPDATE_T _update,
            input bit                  _init=1'b0
        );
        state_vif.cb.update <= _update;
        state_vif.cb.init   <= _init;
        _req(_id, UPDATE_CTXT_DATAPATH);
        state_vif.cb.update <= 'x;
        state_vif.cb.init   <= 'x;
    endtask

    task reap_req(
            input ID_T _id
        );
        _req(_id, UPDATE_CTXT_REAP);
    endtask

    task control_req(
            input ID_T     _id,
            input UPDATE_T _update,
            input bit                  _init=1'b0
        );
        state_vif.cb.update <= _update;
        state_vif.cb.init   <= _init;
        _req(_id, UPDATE_CTXT_CONTROL);
        state_vif.cb.update <= 'x;
        state_vif.cb.init   <= 1'bx;
    endtask

    task receive_resp(
            output STATE_T _state,
            output bit                 _timeout,
            input  int                 TIMEOUT=0
        );
        _wait_ack(_timeout, TIMEOUT);
        _state = state_vif.cb.state;
    endtask

    task nop(
            input  ID_T _id,
            output bit              _timeout,
            input  int               TIMEOUT = 0
        );
        nop_req(_id);
        _wait_ack(_timeout, TIMEOUT);
    endtask

    task _update(
            input  ID_T     _id,
            input  UPDATE_T _update,
            input  bit                  _init=1'b0,
            output STATE_T  _state,
            output bit                  _timeout,
            input  int                  TIMEOUT=0
        );
        update_req(_id, _update, _init);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    task reap(
            input  ID_T    _id,
            output STATE_T _state,
            output bit                 _timeout,
            input  int                 TIMEOUT = 0
        );
        reap_req(_id);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    task control(
            input  ID_T     _id,
            input  UPDATE_T _update,
            input  bit                  _init=1'b0,
            output STATE_T  _state,
            output bit                  _timeout,
            input  int                  TIMEOUT = 0
        );
        control_req(_id, _update, _init);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    // Readiness timeout counts interface clock cycles; zero disables it.
    task wait_ready(output bit _timeout, input int TIMEOUT=32);
        int cycles = 0;
        _timeout = 0;
        while (!state_vif.cb.rdy) begin
            @(state_vif.cb);
            cycles++;
            if (TIMEOUT > 0 && cycles >= TIMEOUT) begin
                _timeout = 1;
                return;
            end
        end
    endtask

endclass : state_intf_agent
