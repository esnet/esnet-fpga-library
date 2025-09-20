interface state_intf #(
    parameter int ID_WID = 1,
    parameter int STATE_WID = 1,  // State data (e.g. array of counters)
    parameter int UPDATE_WID = 1  // Update data (e.g. byte count for count update)
) (
    input logic clk
);
    // Imports
    import state_pkg::*;

    // Signals
    logic                  rdy;
    logic                  req;
    update_ctxt_t          ctxt;
    logic [ID_WID-1:0]     id;
    logic                  init;
    logic [UPDATE_WID-1:0] update;
    logic                  ack;
    logic [STATE_WID-1:0]  state;

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
            input bit [ID_WID-1:0] _id,
            input update_ctxt_t    _ctxt
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
            input bit [ID_WID-1:0] _id = '0
        );
        _req(_id, UPDATE_CTXT_NOP);
    endtask

    task update_req(
            input bit [ID_WID-1:0]     _id,
            input bit [UPDATE_WID-1:0] _update,
            input bit                  _init=1'b0
        );
        cb.update <= _update;
        cb.init   <= _init;
        _req(_id, UPDATE_CTXT_DATAPATH);
        cb.update <= 'x;
        cb.init   <= 'x;
    endtask

    task reap_req(
            input bit [ID_WID-1:0] _id
        );
        _req(_id, UPDATE_CTXT_REAP);
    endtask

    task control_req(
            input bit [ID_WID-1:0]     _id,
            input bit [UPDATE_WID-1:0] _update,
            input bit                  _init=1'b0
        );
        cb.update <= _update;
        cb.init   <= _init;
        _req(_id, UPDATE_CTXT_CONTROL);
        cb.update <= 'x;
        cb.init   <= 1'bx;
    endtask

    task receive_resp(
            output bit [STATE_WID-1:0] _state,
            output bit                 _timeout,
            input  int                 TIMEOUT=0
        );
        _wait_ack(_timeout, TIMEOUT);
        _state = cb.state;
    endtask

    task nop(
            input  bit [ID_WID-1:0] _id,
            output bit              _timeout,
            input  int               TIMEOUT = 0
        );
        nop_req(_id);
        _wait_ack(_timeout, TIMEOUT);
    endtask

    task _update(
            input  bit [ID_WID-1:0]     _id,
            input  bit [UPDATE_WID-1:0] _update,
            input  bit                  _init=1'b0,
            output bit [STATE_WID-1:0]  _state,
            output bit                  _timeout,
            input  int                  TIMEOUT=0
        );
        update_req(_id, _update, _init);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    task reap(
            input  bit [ID_WID-1:0]    _id,
            output bit [STATE_WID-1:0] _state,
            output bit                 _timeout,
            input  int                 TIMEOUT = 0
        );
        reap_req(_id);
        receive_resp(_state, _timeout, TIMEOUT);
    endtask

    task control(
            input  bit [ID_WID-1:0]     _id,
            input  bit [UPDATE_WID-1:0] _update,
            input  bit                  _init=1'b0,
            output bit [STATE_WID-1:0]  _state,
            output bit                  _timeout,
            input  int                  TIMEOUT = 0
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


module state_intf_parameter_check (
    state_intf from_source,
    state_intf to_target
);
    initial begin
        std_pkg::param_check(from_source.ID_WID,     to_target.ID_WID,      "ID_WID");
        std_pkg::param_check(from_source.STATE_WID,  to_target.STATE_WID,   "STATE_WID");
        std_pkg::param_check(from_source.UPDATE_WID,  to_target.UPDATE_WID, "UPDATE_WID");
    end
endmodule


// State interface source termination helper module
module state_intf_source_term (
    state_intf.source to_target
);
    assign to_target.req = 1'b0;
    assign to_target.ctxt = state_pkg::UPDATE_CTXT_NOP;
    assign to_target.id = '0;
    assign to_target.init = 1'b0;
    assign to_target.update = '0;
endmodule : state_intf_source_term


// State interface target termination helper module
module state_intf_target_term (
    state_intf.target from_source
);
    assign from_source.rdy = 1'b0;
    assign from_source.ack = 1'b0;
    assign from_source.state = '0;
endmodule : state_intf_target_term


// State interface connector helper module
module state_intf_connector (
    state_intf.target from_source,
    state_intf.source to_target
);
    state_intf_parameter_check param_check_0 (.*);

    assign to_target.req = from_source.req;
    assign to_target.ctxt = from_source.ctxt;
    assign to_target.id = from_source.id;
    assign to_target.init = from_source.init;
    assign to_target.update = from_source.update;

    assign from_source.rdy = to_target.rdy;
    assign from_source.ack = to_target.ack;
    assign from_source.state = to_target.state;
endmodule : state_intf_connector


// State interface proxy controller
module state_intf_proxy (
    input logic clk,
    input logic srst,
    state_intf.target from_source,
    state_intf.source to_target
);
    state_intf_parameter_check param_check_0 (.*);

    logic pending;
    logic in_progress;

    // Proxy requests
    initial pending = 1'b0;
    always @(posedge clk) begin
        if (srst)                                    pending <= 1'b0;
        else if (from_source.req && from_source.rdy) pending <= 1'b1;
        else if (to_target.rdy)                      pending <= 1'b0;
    end

    initial in_progress = 1'b0;
    always @(posedge clk) begin
        if (srst)                          in_progress <= 1'b0;
        else if (pending && to_target.rdy) in_progress <= 1'b1;
        else if (to_target.ack)            in_progress <= 1'b0;
    end

    assign to_target.req = pending;
    assign from_source.rdy = !pending && !in_progress;

    // Latch request context
    always_ff @(posedge clk) begin
        if (from_source.req && from_source.rdy) begin
            to_target.ctxt <= from_source.ctxt;
            to_target.id <= from_source.id;
            to_target.init <= from_source.init;
            to_target.update <= from_source.update;
        end
    end

    // Pass response directly
    assign from_source.ack = to_target.ack;
    assign from_source.state = to_target.state;

endmodule : state_intf_proxy

// State interface control mux component
// - muxes between two state interfaces
//   - one of the interfaces carries update requests from datapath
//   - one of the interfaces carries update requests from control plane
// - strict priority is granted to the datapath
// - supports multiple outstanding datapath requests, and a single
//   outstanding control requests at any given time
module state_intf_control_mux #(
    parameter int  NUM_TRANSACTIONS = 32 // Set to at least the maximum number of transactions
                                         // that can be outstanding (from the perspective of
                                         // this module) at any given time
) (
    input logic clk,
    input logic srst,
    state_intf.target from_datapath,
    state_intf.target from_control,
    state_intf.source to_target
);
    // Parameters
    localparam int ID_WID = to_target.ID_WID;
    localparam int STATE_WID = to_target.STATE_WID;
    localparam int UPDATE_WID = to_target.UPDATE_WID;

    // Parameter checking
    state_intf_parameter_check param_check_0 (.from_source(from_datapath), .to_target);
    state_intf_parameter_check param_check_1 (.from_source(from_control), .to_target);

    // Signals
    logic ctrl_sel_in;
    logic ctrl_sel_out;

    // Interfaces
    state_intf #(.ID_WID(ID_WID), .STATE_WID(STATE_WID), .UPDATE_WID(UPDATE_WID)) __from_control (.clk);

    // Proxy control requests
    // (enforces at most one outstanding control transaction)
    state_intf_proxy i_state_intf_proxy (
        .clk,
        .srst,
        .from_source ( from_control ),
        .to_target   ( __from_control )
    );

    // Grant strict priority to datapath transactions
    assign ctrl_sel_in = from_datapath.req ? 0 : 1;

    assign from_datapath.rdy = 1'b1;
    assign __from_control.rdy = ctrl_sel_in;

    // Mux between datapath and control interfaces
    assign to_target.ctxt   = ctrl_sel_in ? __from_control.ctxt   : from_datapath.ctxt;
    assign to_target.req    = ctrl_sel_in ? __from_control.req    : from_datapath.req;
    assign to_target.id     = ctrl_sel_in ? __from_control.id     : from_datapath.id;
    assign to_target.init   = ctrl_sel_in ? __from_control.init   : from_datapath.init;
    assign to_target.update = ctrl_sel_in ? __from_control.update : from_datapath.update;

    // Maintain context for open transactions
    fifo_small_ctxt #(
        .DATA_WID ( 1 ),
        .DEPTH    ( NUM_TRANSACTIONS )
    ) i_fifo_small_ctxt (
        .clk     ( clk ),
        .srst    ( srst ),
        .wr_rdy  ( ),
        .wr      ( to_target.req && to_target.rdy ),
        .wr_data ( ctrl_sel_in ),
        .rd      ( to_target.ack ),
        .rd_vld  ( ),
        .rd_data ( ctrl_sel_out ),
        .oflow   ( ),
        .uflow   ( )
    );

    // Demux responses
    assign from_datapath.ack = ctrl_sel_out ? 1'b0 : to_target.ack;
    assign from_datapath.state = to_target.state;

    assign __from_control.ack = ctrl_sel_out ? to_target.ack : 1'b0;
    assign __from_control.state = to_target.state;

endmodule

