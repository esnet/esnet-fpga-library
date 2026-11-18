// Clocked verification access to state_event_intf.
class state_event_agent #(
    parameter type ID_T = bit, MSG_T = bit
) extends std_verif_pkg::agent;

    // Interface binding
    localparam int ID_WID = $bits(ID_T);
    localparam int MSG_WID = $bits(MSG_T);
    virtual state_event_intf #(ID_WID, MSG_WID) state_vif;

    function new(input string name="state_event_agent");
        super.new(name);
        this.state_vif = null;
    endfunction

    // Clock control and transaction helpers
    virtual protected task _idle();
        state_vif.cb.evt <= 1'b0;
        state_vif.cb.id  <=   'x;
        state_vif.cb.msg <=   'x;
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(state_vif.cb);
    endtask

    task notify(input ID_T _id, input MSG_T _msg);
        state_vif.cb.evt <= 1'b1;
        state_vif.cb.id  <= _id;
        state_vif.cb.msg <= _msg;
        @(state_vif.cb);
        state_vif.cb.evt <= 1'b0;
        state_vif.cb.id <= 'x;
        state_vif.cb.msg <= 'x;
    endtask

endclass : state_event_agent
