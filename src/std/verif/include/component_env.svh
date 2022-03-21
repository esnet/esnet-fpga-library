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

// Base environment class for 'simple' component verification, where the component
// is characterized as having input/output 'data' interfaces (attached to
// driver/monitor, respectively), and no 'control' interfaces.
class component_env #(
    parameter type TRANSACTION_IN_T = transaction,
    parameter type TRANSACTION_OUT_T = transaction,
    parameter type DRIVER_T=driver#(TRANSACTION_IN_T),
    parameter type MONITOR_T=monitor#(TRANSACTION_OUT_T),
    parameter type MODEL_T=model#(TRANSACTION_IN_T,TRANSACTION_OUT_T),
    parameter type SCOREBOARD_T=scoreboard#(TRANSACTION_OUT_T)
) extends env;

    local static const string __CLASS_NAME = "std_verif_pkg::component_env";

    //===================================
    // Properties
    //===================================
    DRIVER_T     driver;
    MONITOR_T    monitor;
    MODEL_T      model;
    SCOREBOARD_T scoreboard;

    mailbox #(TRANSACTION_IN_T)  inbox;

    local mailbox #(TRANSACTION_IN_T) __drv_inbox;
    local mailbox #(TRANSACTION_IN_T) __model_inbox;
    local mailbox #(TRANSACTION_OUT_T) __mon_outbox;
    local mailbox #(TRANSACTION_OUT_T) __model_outbox;

    local event __stop;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="component_env");
        super.new(name);
        inbox = new();
        __drv_inbox = new();
        __mon_outbox = new();
        __model_inbox = new();
        __model_outbox = new();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set debug level (verbosity)
    // [[ overrides std_verif_pkg::base.set_debug_level() ]]
    function automatic void set_debug_level(input int DEBUG_LEVEL);
        super.set_debug_level(DEBUG_LEVEL);
        driver.set_debug_level(DEBUG_LEVEL);
        monitor.set_debug_level(DEBUG_LEVEL);
        model.set_debug_level(DEBUG_LEVEL);
        scoreboard.set_debug_level(DEBUG_LEVEL);
    endfunction

    // Connect environment objects
    // [[ implements std_verif_pkg::component.connect() ]]
    function automatic void connect();
        trace_msg("connect()");
        driver.inbox = __drv_inbox;
        model.inbox = __model_inbox;
        model.outbox = __model_outbox;
        monitor.outbox = __mon_outbox;
        scoreboard.got_inbox = __mon_outbox;
        scoreboard.exp_inbox = __model_outbox;
        trace_msg("connect() Done.");
    endfunction

    // Reset environment
    // [[ implements std_verif_pkg::component.reset() ]]
    function automatic void reset();
        trace_msg("reset()");
        driver.reset();
        monitor.reset();
        model.reset();
        scoreboard.reset();
        trace_msg("reset() Done.");
    endfunction

    // Put all (driven) interfaces into quiescent state
    // [[ implements env.idle() ]]
    task idle();
        trace_msg("idle()");
        fork
            driver.idle();
            monitor.idle();
        join
        trace_msg("idle() Done.");
    endtask

    // Start environment execution
    // [[ implements std_verif_pkg::component._start() ]]
    task _start();
        trace_msg("start()");
        info_msg("Starting environment...");
        fork
            begin
                driver.start();
            end
            begin
                monitor.start();
            end
            begin
                model.start();
            end
            begin
                scoreboard.start();
            end
            begin
                fork
                    begin
                        forever begin
                            TRANSACTION_IN_T transaction;
                            inbox.get(transaction);
                            __drv_inbox.put(transaction);
                            __model_inbox.put(transaction);
                        end
                    end
                    begin
                        wait(__stop.triggered);
                    end
                join_any
                disable fork;
            end
        join_none
        trace_msg("_start() Done.");
    endtask

    // Stop environment execution
    // [[ overrides std_verif_pkg::component.stop() ]]
    task stop();
        trace_msg("stop()");
        info_msg("Stopping environment...");
        super.stop();
        driver.stop();
        monitor.stop();
        model.stop();
        scoreboard.stop();
        trace_msg("stop() Done.");
    endtask

endclass : component_env
