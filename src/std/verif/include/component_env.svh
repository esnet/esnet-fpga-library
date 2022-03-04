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
    //===================================
    // Properties
    //===================================
    DRIVER_T     driver;
    MONITOR_T    monitor;
    MODEL_T      model;
    SCOREBOARD_T scoreboard;

    mailbox #(TRANSACTION_IN_T)  src_mailbox;
    mailbox #(TRANSACTION_OUT_T) exp_mailbox;
    mailbox #(TRANSACTION_OUT_T) got_mailbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="component_env");
        super.new(name);
        debug_msg("--- component_env.build() ---");
        src_mailbox = new();
        exp_mailbox = new();
        got_mailbox = new();
        debug_msg("--- component_env.build() Done. ---");
    endfunction

    // Set debug level (verbosity)
    // [[ overrides std_verif_pkg::base.set_debug_level() superclass method ]]
    function automatic void set_debug_level(input int DEBUG_LEVEL);
        super.set_debug_level(DEBUG_LEVEL);
        driver.set_debug_level(DEBUG_LEVEL);
        monitor.set_debug_level(DEBUG_LEVEL);
        model.set_debug_level(DEBUG_LEVEL);
        scoreboard.set_debug_level(DEBUG_LEVEL);
    endfunction

    // Connect environment objects
    // [[ implements env.connect() superclass method ]]
    function automatic void connect();
        debug_msg("--- component_env.connect() ---");
        driver.inbox = src_mailbox;
        model.inbox = src_mailbox;
        model.outbox = exp_mailbox;
        monitor.outbox = got_mailbox;
        scoreboard.got_inbox = got_mailbox;
        scoreboard.exp_inbox = exp_mailbox;
        debug_msg("--- component_env.connect() Done. ---");
    endfunction

    // Reset environment
    // [[ implements env.reset() superclass method ]]
    function automatic void reset();
        debug_msg("--- component_env.reset() ---");
        driver.reset();
        monitor.reset();
        model.reset();
        scoreboard.reset();
        debug_msg("--- component_env.reset() Done. ---");
    endfunction

    // Put all (driven) interfaces into quiescent state
    // [[ implements env.idle() virtual method ]]
    task idle();
        debug_msg("--- component_env.idle() ---");
        fork
            driver.idle();
            monitor.idle();
        join
        debug_msg("--- component_env.idle() Done. ---");
    endtask

    // Wait for environment to be ready for transactions (after init/reset for example)
    // [[ overrides superclass wait_ready() method ]]
    task wait_ready();
        debug_msg("--- component_env.wait_ready() ---");
        fork
            super.wait_ready();
            driver.wait_ready();
        join
        debug_msg("--- component_env.wait_ready() Done. ---");
    endtask

endclass : component_env
