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

// Base environment class for 'controlled' component verification, where the component
// is characterized as having input/output 'data' interfaces (attached to
// driver/monitor, respectively), and a 'control' interface (attached to an agent).
class component_ctrl_env #(
    parameter type TRANSACTION_IN_T = transaction,
    parameter type TRANSACTION_OUT_T = transaction,
    parameter type DRIVER_T=driver#(TRANSACTION_IN_T),
    parameter type MONITOR_T=monitor#(TRANSACTION_OUT_T),
    parameter type MODEL_T=model#(TRANSACTION_IN_T,TRANSACTION_OUT_T),
    parameter type SCOREBOARD_T=scoreboard#(TRANSACTION_OUT_T),
    parameter type AGENT_T = agent
) extends component_env#(TRANSACTION_IN_T, TRANSACTION_OUT_T, DRIVER_T, MONITOR_T, MODEL_T, SCOREBOARD_T);
    
    //===================================
    // Properties
    //===================================
    AGENT_T   agent;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="component_ctrl_env");
        super.new(name);
    endfunction

    // Set debug level (verbosity)
    // [[ overrides std_verif_pkg::base.set_debug_level() superclass method ]]
    function automatic void set_debug_level(input int DEBUG_LEVEL);
        super.set_debug_level(DEBUG_LEVEL);
        agent.set_debug_level(DEBUG_LEVEL);
    endfunction

    // Reset environment
    // [[ overrides env_component.reset() superclass method ]]
    function automatic void reset();
        debug_msg("--- component_ctrl_env.reset() ---");
        super.reset();
        agent.reset();
        debug_msg("--- component_ctrl_env.reset() Done. ---");
    endfunction

    // Put all (driven) interfaces into quiescent state
    // [[ overrides env_component.idle() superclass method ]]
    task idle();
        debug_msg("--- component_ctrl_env.idle() ---");
        fork
            super.idle();
            agent.idle();
        join
        debug_msg("--- component_ctrl_env.idle() Done. ---");
    endtask

    // Wait for environment to be ready for transactions (after init/reset for example)
    // [[ overrides superclass wait_ready() method ]]
    task wait_ready();
        debug_msg("--- component_ctrl_env.wait_ready() ---");
        fork
            super.wait_ready();
            agent.wait_ready();
        join
        debug_msg("--- component_ctrl_env.wait_ready() Done. ---");
    endtask

endclass
