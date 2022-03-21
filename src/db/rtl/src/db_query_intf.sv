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

interface db_query_intf #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[31:0]
) (
    input logic clk
);

    // Signals
    // -- Requester to responder
    logic     req;
    KEY_T     key;

    // -- Responder to requester
    logic     rdy;
    logic     ack;
    logic     valid;
    VALUE_T   value;

    modport requester(
        input  rdy,
        output req,
        input  ack,
        output key,
        input  valid,
        input  value
    );

    modport responder(
        output rdy,
        input  req,
        output ack,
        input  key,
        output valid,
        output value
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        output key;
        input rdy, ack, valid, value;
        inout req;
    endclocking

    task _wait(input int cycles);
        repeat(cycles) @(cb);
    endtask

    task idle();
        cb.req <= 1'b0;
    endtask

    task send(
            input KEY_T _key
        );
        cb.req <= 1'b1;
        cb.key <= _key;
        @(cb);
        wait (cb.req && cb.rdy);
        cb.req <= 1'b0;
    endtask

    task receive(
            output bit _valid,
            output VALUE_T _value
        );
        @(cb);
        wait(cb.ack);
        _valid = cb.valid;
        _value = cb.value;
    endtask

    task _query(
            input KEY_T _key,
            output bit _valid,
            output VALUE_T _value
        );
        send(_key);
        receive(_valid, _value);
    endtask

    task query(
            input KEY_T _key,
            output bit _valid,
            output VALUE_T _value,
            output bit _timeout,
            input int TIMEOUT=64
        );
        fork
            begin
                fork
                    begin
                        _query(_key, _valid, _value);
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

endinterface : db_query_intf


// Key-value query requester termination helper module
module db_query_intf_requester_term (
    db_query_intf.requester query_if
);
    // Tie off controller outputs
    assign query_if.req = 1'b0;
    assign query_if.key = '0;

endmodule : db_query_intf_requester_term


// Key-value query responder termination helper module
module db_query_intf_responder_term (
    db_query_intf.responder query_if
);
    // Tie off controller outputs
    assign query_if.rdy = 1'b0;
    assign query_if.ack = 1'b0;
    assign query_if.valid = 1'b0;
    assign query_if.value = '0;

endmodule : db_query_intf_responder_term

// Key-value query (back-to-back) connector helper module
module db_query_intf_connector (
    db_query_intf.responder query_if_from_requester,
    db_query_intf.requester query_if_to_responder
);
    // Connect signals (requester -> responder)
    assign query_if_to_responder.req = query_if_from_requester.req;
    assign query_if_to_responder.key = query_if_from_requester.key;

    // Connect signals (responder -> requester)
    assign query_if_from_requester.rdy = query_if_to_responder.rdy;
    assign query_if_from_requester.ack = query_if_to_responder.ack;
    assign query_if_from_requester.valid = query_if_to_responder.valid;
    assign query_if_from_requester.value = query_if_to_responder.value;

endmodule : db_query_intf_connector
