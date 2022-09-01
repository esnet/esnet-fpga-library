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

interface state_update_intf #(
    parameter type ID_T = logic[7:0],
    parameter type UPDATE_T = logic, // Update data type (e.g. byte count for count update)
    parameter type STATE_T = logic   // State data type (e.g. array of counters)
) (
    input logic clk
);

    // Signals
    logic    rdy;
    logic    req;
    ID_T     id;
    logic    init;
    UPDATE_T update;   
    logic    ack;
    STATE_T  state;

    modport source(
        input  rdy,
        output req,
        output id,
        output init,
        output update,
        input  ack,
        input  state
    );

    modport target(
        output rdy,
        input  req,
        input  id,
        input  init,
        input  update,
        output ack,
        output state
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        output id, init, update;
        input  rdy, ack, state;
        inout  req;
    endclocking

    task idle();
        cb.req    <= 1'b0;
        cb.id     <=   'x;
        cb.init   <= 1'bx;
        cb.update <=   'x;
        @(cb);
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    // Send update
    task send(
            input ID_T     _id,
            input UPDATE_T _update,
            input bit      _init
        );
        cb.req    <= 1'b1;
        cb.id     <= _id;
        cb.update <= _update;
        cb.init   <= _init;
        @(cb);
        wait(cb.req && cb.rdy);
        cb.req    <= 1'b0;
        cb.id     <= 'x;
        cb.update <= 'x;
        cb.init   <= 'x;
    endtask

    // Receive result
    task receive(
            output STATE_T _state,
            output bit     _timeout,
            input  int     TIMEOUT=0
        );
        fork
            begin
                fork
                    begin
                        @(cb);
                        wait(cb.ack);
                        _state = cb.state;
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

endinterface : state_update_intf
