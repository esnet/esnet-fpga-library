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

interface db_intf #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[31:0],
    parameter int XIDS = 1 // Set to maximum number of transactions in-flight
                            // (due to latency + pipelining, etc.)
) (
    input logic clk
);
    // Parameters
    localparam int XID_WID = $clog2(XIDS);

    // Typedefs
    typedef logic [XID_WID-1:0] XID_T;

    // Signals
    logic     req;
    KEY_T     key;
    XID_T     req_id;


    logic     rdy;
    logic     ack;
    logic     error;
    XID_T     ack_id;

    logic     valid;
    VALUE_T   value;

    modport requester(
        input  rdy,
        output req,
        output req_id,
        input  ack,
        input  error,
        input  ack_id,
        output key,
        inout  valid, // Input for query interface, output for update interface
        inout  value  // Input for query interface, output for update interface
    );

    modport responder(
        output rdy,
        input  req,
        input  req_id,
        output ack,
        output ack_id,
        output error,
        input  key,
        inout  valid, // Output for query interface, input for update interface
        inout  value  // Output for query interface, input for update interface
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        output key, req_id;
        input rdy, ack, error, ack_id;
        inout req, valid, value;
    endclocking

    task _wait(input int cycles);
        repeat(cycles) @(cb);
    endtask

    task idle();
        cb.req <= 1'b0;
    endtask

    task send(
            input KEY_T _key,
            input XID_T _xid = 0
        );
        cb.req <= 1'b1;
        cb.key <= _key;
        cb.req_id <= _xid;
        @(cb);
        wait (cb.req && cb.rdy);
        cb.req <= 1'b0;
    endtask

    task wait_ack(
            output bit _error,
            output XID_T _xid
        );
        @(cb);
        wait(cb.ack);
        _error = cb.error;
        _xid = cb.ack_id;
    endtask

    task wait_ack_xid(
            input XID_T _xid,
            output bit _error
        );
        XID_T _ack_id;
        do
            wait_ack(_error, _ack_id);
        while (_ack_id !== _xid);
    endtask

    task receive(
            output bit _valid,
            output VALUE_T _value,
            output bit _error,
            output XID_T _xid
        );
        wait_ack(_error, _xid);
        _valid = cb.valid;
        _value = cb.value;
    endtask

    task receive_xid(
            output bit _valid,
            output VALUE_T _value,
            output bit _error,
            input XID_T _xid
        );
        wait_ack_xid(_xid, _error);
        _valid = cb.valid;
        _value = cb.value;
    endtask

    task _query(
            input KEY_T _key,
            input XID_T _xid,
            output bit _valid,
            output VALUE_T _value,
            output bit _error
        );
        send(_key, _xid);
        receive_xid(_valid, _value, _error, _xid);
    endtask

    task query(
            input KEY_T _key,
            input XID_T _xid,
            output bit _valid,
            output VALUE_T _value,
            output bit _error,
            output bit _timeout,
            input int TIMEOUT=64
        );
        fork
            begin
                fork
                    begin
                        _query(_key, _xid, _valid, _value, _error);
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

    task post_update(
            input KEY_T _key,
            input bit _valid,
            input VALUE_T _value,
            input XID_T _xid = 0
        );
        cb.valid = _valid;
        cb.value = _value;
        send(_key, _xid);
    endtask

    task _update(
            input KEY_T _key,
            input bit _valid,
            input VALUE_T _value,
            input XID_T _xid,
            output bit _error
        );
        post_update(_key, _valid, _value, _xid);
        wait_ack_xid(_error, _xid);
    endtask

    task update(
            input KEY_T _key,
            input bit _valid,
            input VALUE_T _value,
            input XID_T _xid,
            output bit _error,
            output bit _timeout,
            input int TIMEOUT=64
        );
        fork
            begin
                fork
                    begin
                        _update(_key, _valid, _value, _xid, _error);
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

    task wait_ready(
            output bit timeout,
            input int TIMEOUT=32
        );
        timeout = 1'b0;
        fork
            begin
                fork
                    begin
                        wait(cb.rdy);
                    end
                    begin
                        if (TIMEOUT > 0) begin
                            _wait(TIMEOUT);
                            timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
    endtask

endinterface : db_intf


// DB interface requester termination helper module
module db_intf_requester_term (
    db_intf.requester db_if
);
    // Tie off requester outputs
    assign db_if.req = 1'b0;
    assign db_if.key = '0;
    assign db_if.req_id = '0;

endmodule : db_intf_requester_term


// DB interface responder termination helper module
module db_intf_responder_term (
    db_intf.responder db_if
);
    // Tie off responder outputs
    assign db_if.rdy = 1'b0;
    assign db_if.ack = 1'b0;
    assign db_if.error = 1'b0;
    assign db_if.ack_id = '0;

endmodule : db_intf_responder_term

// DB interface connector helper module
module db_intf_connector (
    db_intf.responder db_if_from_requester,
    db_intf.requester db_if_to_responder
);

    assign db_if_to_responder.req = db_if_from_requester.req;
    assign db_if_to_responder.key = db_if_from_requester.key;
    assign db_if_to_responder.req_id = db_if_from_requester.req_id;

    assign db_if_to_requester.rdy = db_if_from_responder.rdy;
    assign db_if_to_requester.ack = db_if_from_responder.ack;
    assign db_if_to_requester.error = db_if_from_responder.error;
    assign db_if_to_requester.ack_id = db_if_from_responder.ack_id;

    // Connect valid/value inout ports as both input and output
    // (expect application to drive appropriately depending on whether
    //  interface is used as write interface or read interface)
    assign db_if_from_requester.valid = db_if_to_responder.valid;
    assign db_if_from_requester.value = db_if_to_responder.value;
    assign db_if_to_responder.valid = db_if_from_requester.valid;
    assign db_if_to_responder.value = db_if_from_requester.value;

endmodule

// Database interface static mux component
// - provides mux between two database interfaces
// - can mux either read interfaces or write interfaces
module db_intf_mux (
    input logic        clk,
    input logic        srst,
    input logic        mux_sel,
    db_intf.responder  db_if_from_requester_0,
    db_intf.responder  db_if_from_requester_1,
    db_intf.requester  db_if_to_responder
);
    // Parameters
    localparam int CTXT_FIFO_DEPTH = db_if_to_responder.XIDS;
    localparam int CTXT_PTR_WID = $clog2(CTXT_FIFO_DEPTH);

    // Signals
    logic [CTXT_FIFO_DEPTH-1:0] if_ctxt;
    logic [CTXT_PTR_WID-1:0] ctxt_wr_ptr;
    logic [CTXT_PTR_WID-1:0] ctxt_rd_ptr;
    logic demux_sel;

    // Mux requests
    assign db_if_to_responder.req    = mux_sel ? db_if_from_requester_1.req    : db_if_from_requester_0.req;
    assign db_if_to_responder.key    = mux_sel ? db_if_from_requester_1.key    : db_if_from_requester_0.key;
    assign db_if_to_responder.req_id = mux_sel ? db_if_from_requester_1.req_id : db_if_from_requester_0.req_id;

    assign db_if_from_requester_0.rdy = mux_sel ? 1'b0 : db_if_to_responder.rdy;
    assign db_if_from_requester_1.rdy = mux_sel ? db_if_to_responder.rdy : 1'b0;

    // Maintain context for open transactions
    initial begin
        if_ctxt = '0;
        ctxt_wr_ptr = '0;
    end
    always @(posedge clk) begin
        if (srst) begin
            if_ctxt <= '0;
            ctxt_wr_ptr <= '0;
        end else if (db_if_to_responder.req && db_if_to_responder.rdy) begin
            if_ctxt[ctxt_wr_ptr] <= mux_sel;
            ctxt_wr_ptr <= ctxt_wr_ptr + 1;
        end
    end

    initial ctxt_rd_ptr = 0;
    always @(posedge clk) begin
        if (srst) ctxt_rd_ptr <= 0;
        else if (db_if_to_responder.ack) ctxt_rd_ptr <= ctxt_rd_ptr + 1;
    end

    // Demux response
    assign demux_sel = if_ctxt[ctxt_rd_ptr];

    // Demux responses
    assign db_if_from_requester_0.ack   = demux_sel ? 1'b0 : db_if_to_responder.ack;
    assign db_if_from_requester_0.error = demux_sel ? 1'b0 : db_if_to_responder.error;

    assign db_if_from_requester_1.ack   = demux_sel ? db_if_to_responder.ack   : 1'b0;
    assign db_if_from_requester_1.error = demux_sel ? db_if_to_responder.error : 1'b0;

    assign db_if_from_requester_0.ack_id = db_if_to_responder.ack_id;
    assign db_if_from_requester_1.ack_id = db_if_to_responder.ack_id;

    // Connect valid/value inout ports as both input and output
    // (expect application to drive appropriately depending on whether
    //  interface is used as write interface or read interface)
    assign db_if_from_requester_0.valid = db_if_to_responder.valid;
    assign db_if_from_requester_0.value = db_if_to_responder.value;
    assign db_if_from_requester_1.valid = db_if_to_responder.valid;
    assign db_if_from_requester_1.value = db_if_to_responder.value;
    assign db_if_to_responder.valid = mux_sel ? db_if_from_requester_1.valid : db_if_from_requester_0.valid;
    assign db_if_to_responder.value = mux_sel ? db_if_from_requester_1.value : db_if_from_requester_0.value;

endmodule : db_intf_mux


// Database interface priority mux component
// - muxes between two database (read) interfaces, with strict
//   priority granted to the hi_prio interface
module db_intf_prio_mux (
    input logic clk,
    input logic srst,
    db_intf.responder db_if_from_requester_hi_prio,
    db_intf.responder db_if_from_requester_lo_prio,
    db_intf.requester db_if_to_responder
);
    // Signals
    logic mux_sel;

    assign mux_sel = db_if_from_requester_hi_prio.req ? 0 : 1;

    // Mux
    db_intf_mux i_db_intf_mux (
        .clk ( clk ),
        .srst ( srst ),
        .mux_sel ( mux_sel ),
        .db_if_from_requester_0 ( db_if_from_requester_hi_prio ),
        .db_if_from_requester_1 ( db_if_from_requester_lo_prio ),
        .db_if_to_responder     ( db_if_to_responder )
    );

endmodule : db_intf_prio_mux
