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

interface db_update_intf #(
    parameter type KEY_T = logic[7:0],
    parameter type VALUE_T = logic[31:0],
    parameter type DATA_T = logic[31:0]
) (
    input logic clk
);

    // Signals
    // -- Requester to responder
    logic     req;
    logic     upd;
    KEY_T     key;
    DATA_T    data;

    // -- Responder to requester
    logic     rdy;
    logic     ack;
    logic     valid;
    VALUE_T   value;

    modport requester(
        output req,
        output upd,
        output key,
        output data,
        input  rdy,
        input  ack,
        input  valid,
        input  value
    );

    modport responder(
        input  req,
        input  upd,
        input  key,
        input  data,
        output rdy,
        output ack,
        output valid,
        output value
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        output key, upd, data;
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
            input bit _upd,
            input KEY_T _key,
            input DATA_T _data
        );
        cb.req <= 1'b1;
        cb.upd <= _upd;
        cb.key <= _key;
        cb.data <= _data;
        wait (cb.req && cb.rdy);
        cb.req <= 1'b0;
    endtask

    task receive(
            output bit _valid,
            output VALUE_T _value
        );
        wait(cb.ack);
        _valid = cb.valid;
        _value = cb.value;
    endtask

    task _transact(
            input bit _upd,
            input KEY_T _key,
            input DATA_T _data,
            output bit _valid,
            output VALUE_T _value
        );
        send(_upd, _key, _data);
        receive(_valid, _value);
    endtask

    task transact(
            input bit _upd,
            input KEY_T _key,
            input DATA_T _data,
            output bit _valid,
            output VALUE_T _value,
            output bit _timeout,
            input int TIMEOUT=0
        );
        fork
            begin
                fork
                    begin
                        _transact(_upd, _key, _data, _valid, _value);
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

    task query(
            input KEY_T _key,
            output bit _valid,
            output bit _value,
            output bit _timeout,
            input int TIMEOUT=0
        );
        transact(1'b0, _key, 'x, _valid, _value, _timeout, TIMEOUT);
    endtask

    task update(
            input KEY_T _key,
            input DATA_T _data,
            output bit _valid,
            output bit _value,
            output bit _timeout,
            input int TIMEOUT=0
        );
        transact(1'b1, _key, _data, _valid, _value, _timeout, TIMEOUT);
    endtask

    task wait_ready(
            output bit timeout,
            input int TIMEOUT=0
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

endinterface : db_update_intf


// Key-value update requester termination helper module
module db_update_intf_requester_term (
    db_update_intf.requester update_if
);
    // Tie off controller outputs
    assign update_if.req = 1'b0;
    assign update_if.upd = 1'b0;
    assign update_if.key = '0;
    assign update_if.data = '0;

endmodule : db_update_intf_requester_term


// Key-value update responder termination helper module
module db_update_intf_responder_term (
    db_update_intf.responder update_if
);
    // Tie off controller outputs
    assign update_if.rdy = 1'b0;
    assign update_if.ack = 1'b0;
    assign update_if.valid = 1'b0;
    assign update_if.value = '0;

endmodule : db_update_intf_responder_term

// Key-value update (back-to-back) connector helper module
module db_update_intf_connector (
    db_update_intf.responder update_if_from_requester,
    db_update_intf.requester update_if_to_responder
);
    // Connect signals (requester -> responder)
    assign update_if_to_responder.req = update_if_from_requester.req;
    assign update_if_to_responder.key = update_if_from_requester.key;

    // Connect signals (responder -> requester)
    assign update_if_from_requester.rdy = update_if_to_responder.rdy;
    assign update_if_from_requester.ack = update_if_to_responder.ack;
    assign update_if_from_requester.valid = update_if_to_responder.valid;
    assign update_if_from_requester.value = update_if_to_responder.value;

endmodule : db_update_intf_connector
