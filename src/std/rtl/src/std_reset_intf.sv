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

interface std_reset_intf #(
    parameter bit ACTIVE_LOW = 1'b0,  // Specify active-low (ACTIVE_LOW = 1'b1)
                                      // or active-high (ACTIVE_LOW = 1'b0, default) operation
    parameter logic INIT_VALUE = ACTIVE_LOW ? 1'b0 : 1'b1 // Initial state of reset signal
                                                          // (default: reset asserted)
) (
    input clk
);
    // Local parameters
    localparam logic ASSERT_VALUE   = ACTIVE_LOW ? 1'b0 : 1'b1;
    localparam logic DEASSERT_VALUE = ACTIVE_LOW ? 1'b1 : 1'b0;

    // Signals
    logic reset;
    logic ready;

    // Modports
    modport controller (
        output reset,
        input  ready
    );

    modport peripheral (
        input  reset,
        output ready
    );

    clocking cb @(posedge clk);
        default input #1step output #1step;
        input ready;
        output reset;
    endclocking

    // Initialization
    initial reset = INIT_VALUE;

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    // Tasks
    task assert_sync();
        cb.reset <= ASSERT_VALUE;
        @(cb);
    endtask

    task assert_async();
        reset = ASSERT_VALUE;
    endtask

    task deassert_sync();
        cb.reset <= DEASSERT_VALUE;
        @(cb);
    endtask

    task deassert_async();
        reset = DEASSERT_VALUE;
    endtask

    task wait_ready(output bit _timeout, input int TIMEOUT=0);
        fork
            begin
                fork
                    begin
                        wait(cb.ready);
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

    task pulse(input int cycles=1);
        assert_sync();
        _wait(cycles);
        deassert_sync();
        @(cb);
    endtask

endinterface : std_reset_intf
