interface state_intf #(
    parameter type ID_T = logic[7:0],
    parameter type STATE_T = logic,  // State data type (e.g. array of counters)
    parameter type UPDATE_T = logic  // Update data type (e.g. byte count for count update)
) (
    input logic clk
);
    // Imports
    import state_pkg::*;

    // Signals
    logic         rdy;
    logic         req;
    update_ctxt_t ctxt;
    ID_T          id;
    logic         init;
    UPDATE_T      update;
    logic         ack;
    STATE_T       state;

    modport source(
        input  rdy,
        output req,
        output ctxt,
        output id,
        output init,
        output update,
        input  ack,
        input  state
    );

    modport target(
        output rdy,
        input  req,
        input  ctxt,
        input  id,
        input  init,
        input  update,
        output ack,
        output state
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        output id, init, update, ctxt;
        input  rdy, ack, state;
        inout  req;
    endclocking

    task idle();
        cb.req    <= 1'b0;
        cb.ctxt   <= UPDATE_CTXT_NOP;
        cb.id     <=   'x;
        cb.init   <= 1'bx;
        cb.update <=   'x;
        @(cb);
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task _req(
            input ID_T          _id,
            input update_ctxt_t _ctxt
        );
        cb.req  <= 1'b1;
        cb.id   <= _id;
        cb.ctxt <= _ctxt;
        @(cb);
        wait(cb.req && cb.rdy);
        cb.req  <= 1'b0;
        cb.id   <= 'x;
        cb.ctxt <= UPDATE_CTXT_NOP;
    endtask

    task _wait_ack(
            output bit _timeout,
            input  int TIMEOUT=0
        );
        fork
            begin
                fork
                    begin
                        @(cb);
                        wait(cb.ack);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) _wait(TIMEOUT);
                        else forever     _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

    task nop_req(
            input ID_T _id = '0
        );
        _req(_id, UPDATE_CTXT_NOP);
    endtask

    task update_req(
            input ID_T     _id,
            input UPDATE_T _update,
            input bit      _init=1'b0
        );
        cb.update <= _update;
        cb.init   <= _init;
        _req(_id, UPDATE_CTXT_DATAPATH);
        cb.update <= 'x;
        cb.init   <= 'x;
    endtask

    task reap_req(
            input ID_T   _id
        );
        _req(_id, UPDATE_CTXT_REAP);
    endtask

    task control_req(
            input ID_T    _id,
            input UPDATE_T _update,
            input bit      _init=1'b0
        );
        cb.update <= _update;
        cb.init   <= _init;
        _req(_id, UPDATE_CTXT_CONTROL);
        cb.update <= 'x;
        cb.init   <= 1'bx;
    endtask

    task receive_resp(
            output STATE_T _state,
            output bit     _timeout,
            input  int     TIMEOUT=0
        );
        _wait_ack(_timeout, TIMEOUT);
        _state = cb.state;
    endtask

    task nop(
            input ID_T _id,
            output bit _timeout,
            input int TIMEOUT = 0
        );
        nop_req(_id);
        _wait_ack(_timeout, TIMEOUT);
    endtask

    task _update(
            input ID_T     _id,
            input UPDATE_T _update,
            input bit      _init=1'b0,
            output STATE_T _state,
            output bit     _timeout,
            input int TIMEOUT=0
        );
        update_req(_id, _update, _init);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    task reap(
            input ID_T     _id,
            output STATE_T _state,
            output bit     _timeout,
            input int TIMEOUT = 0
        );
        reap_req(_id);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    task control(
            input ID_T     _id,
            input UPDATE_T _update,
            input bit      _init=1'b0,
            output STATE_T _state,
            output bit     _timeout,
            input int TIMEOUT = 0
        );
        control_req(_id, _update, _init);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    task wait_ready(
            output bit _timeout,
            input  int TIMEOUT=32
        );
        fork
            begin
                fork
                    begin
                        wait(cb.rdy);
                    end
                    begin
                        _timeout = 1'b0;
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

endinterface : state_intf


// State interface source termination helper module
module state_intf_source_term (
    state_intf.source state_if
);
    assign state_if.req = 1'b0;
    assign state_if.ctxt = '0;
    assign state_if.id = '0;
    assign state_if.init = 1'b0;
    assign state_if.update = '0;
endmodule : state_intf_source_term


// State interface target termination helper module
module state_intf_target_term (
    state_intf.target state_if
);
    assign state_if.rdy = 1'b0;
    assign state_if.ack = 1'b0;
    assign state_if.state = '0;
endmodule : state_intf_target_term


// State interface connector helper module
module state_intf_connector (
    state_intf.target state_if_from_source,
    state_intf.source state_if_to_target
);
    assign state_if_to_target.req = state_if_from_source.req;
    assign state_if_to_target.ctxt = state_if_from_source.ctxt;
    assign state_if_to_target.id = state_if_from_source.id;
    assign state_if_to_target.init = state_if_from_source.init;
    assign state_if_to_target.update = state_if_from_source.update;

    assign state_if_from_source.rdy = state_if_to_target.rdy;
    assign state_if_from_source.ack = state_if_to_target.ack;
    assign state_if_from_source.state = state_if_to_target.state;
endmodule : state_intf_connector


// State interface proxy controller
module state_intf_proxy (
    input logic clk,
    input logic srst,
    state_intf.target state_if_from_source,
    state_intf.source state_if_to_target
);
    logic pending;
    logic in_progress;

    // Proxy requests
    initial pending = 1'b0;
    always @(posedge clk) begin
        if (srst)                                                      pending <= 1'b0;
        else if (state_if_from_source.req && state_if_from_source.rdy) pending <= 1'b1;
        else if (state_if_to_target.rdy)                               pending <= 1'b0;
    end

    initial in_progress = 1'b0;
    always @(posedge clk) begin
        if (srst)                                   in_progress <= 1'b0;
        else if (pending && state_if_to_target.rdy) in_progress <= 1'b1;
        else if (state_if_to_target.ack)            in_progress <= 1'b0;
    end

    assign state_if_to_target.req = pending;
    assign state_if_from_source.rdy = !pending && !in_progress;

    // Latch request context
    always_ff @(posedge clk) begin
        if (state_if_from_source.req && state_if_from_source.rdy) begin
            state_if_to_target.ctxt <= state_if_from_source.ctxt;
            state_if_to_target.id <= state_if_from_source.id;
            state_if_to_target.init <= state_if_from_source.init;
            state_if_to_target.update <= state_if_from_source.update;
        end
    end

    // Pass response directly
    assign state_if_from_source.ack = state_if_to_target.ack;
    assign state_if_from_source.state = state_if_to_target.state;

endmodule : state_intf_proxy

// State interface control mux component
// - muxes between two state interfaces
//   - one of the interfaces carries update requests from datapath
//   - one of the interfaces carries update requests from control plane
// - strict priority is granted to the datapath
// - supports multiple outstanding datapath requests, and a single
//   outstanding control requests at any given time
module state_intf_control_mux #(
    parameter type ID_T = logic,
    parameter type STATE_T = logic,
    parameter type UPDATE_T = logic,
    parameter int  NUM_TRANSACTIONS = 32 // Set to at least the maximum number of transactions
                                         // that can be outstanding (from the perspective of
                                         // this module) at any given time
) (
    input logic clk,
    input logic srst,
    state_intf.target state_if_from_datapath,
    state_intf.target state_if_from_control,
    state_intf.source state_if_to_target
);
    // Signals
    logic ctrl_sel_in;
    logic ctrl_sel_out;

    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        std_pkg::param_check($bits(state_if_from_datapath.ID_T),     $bits(ID_T),     "state_if_from_datapath.ID_T");
        std_pkg::param_check($bits(state_if_from_datapath.STATE_T),  $bits(STATE_T),  "state_if_from_datapath.STATE_T");
        std_pkg::param_check($bits(state_if_from_datapath.UPDATE_T), $bits(UPDATE_T), "state_if_from_datapath.UPDATE_T");
        std_pkg::param_check($bits(state_if_from_control.ID_T),      $bits(ID_T),     "state_if_from_control.ID_T");
        std_pkg::param_check($bits(state_if_from_control.STATE_T),   $bits(STATE_T),  "state_if_from_control.STATE_T");
        std_pkg::param_check($bits(state_if_from_control.UPDATE_T),  $bits(UPDATE_T), "state_if_from_control.UPDATE_T");
        std_pkg::param_check($bits(state_if_to_target.ID_T),         $bits(ID_T),     "state_if_to_target.ID_T");
        std_pkg::param_check($bits(state_if_to_target.STATE_T),      $bits(STATE_T),  "state_if_to_target.STATE_T");
        std_pkg::param_check($bits(state_if_to_target.UPDATE_T),     $bits(UPDATE_T), "state_if_to_target.UPDATE_T");
    end

    // Interfaces
    state_intf #(.ID_T(ID_T), .STATE_T(STATE_T), .UPDATE_T(UPDATE_T)) __state_if_from_control (.clk(clk));

    // Proxy control requests
    // (enforces at most one outstanding control transaction)
    state_intf_proxy i_state_intf_proxy (
        .clk                  ( clk ),
        .srst                 ( srst ),
        .state_if_from_source ( state_if_from_control ),
        .state_if_to_target   ( __state_if_from_control )
    );

    // Grant strict priority to datapath transactions
    assign ctrl_sel_in = state_if_from_datapath.req ? 0 : 1;

    assign state_if_from_datapath.rdy = 1'b1;
    assign __state_if_from_control.rdy = ctrl_sel_in;

    // Mux between datapath and control interfaces
    assign state_if_to_target.ctxt   = ctrl_sel_in ? __state_if_from_control.ctxt   : state_if_from_datapath.ctxt;
    assign state_if_to_target.req    = ctrl_sel_in ? __state_if_from_control.req    : state_if_from_datapath.req;
    assign state_if_to_target.id     = ctrl_sel_in ? __state_if_from_control.id     : state_if_from_datapath.id;
    assign state_if_to_target.init   = ctrl_sel_in ? __state_if_from_control.init   : state_if_from_datapath.init;
    assign state_if_to_target.update = ctrl_sel_in ? __state_if_from_control.update : state_if_from_datapath.update;

    // Maintain context for open transactions
    fifo_small   #(
        .DATA_T  ( logic ),
        .DEPTH   ( NUM_TRANSACTIONS )
    ) i_fifo_small__ctxt (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr      ( state_if_to_target.req && state_if_to_target.rdy ),
        .wr_data ( ctrl_sel_in ),
        .full    ( ),
        .oflow   ( ),
        .rd      ( state_if_to_target.ack ),
        .rd_data ( ctrl_sel_out ),
        .empty   ( ),
        .uflow   ( )
    );

    // Demux responses
    assign state_if_from_datapath.ack = ctrl_sel_out ? 1'b0 : state_if_to_target.ack;
    assign state_if_from_datapath.state = state_if_to_target.state;

    assign __state_if_from_control.ack = ctrl_sel_out ? state_if_to_target.ack : 1'b0;
    assign __state_if_from_control.state = state_if_to_target.state;

endmodule

