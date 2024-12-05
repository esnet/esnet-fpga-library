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
) extends basic_env;

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
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        driver = null;
        monitor = null;
        model = null;
        scoreboard = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        driver = null;
        monitor = null;
        model = null;
        scoreboard = null;
        inbox = null;
        __drv_inbox = null;
        __model_inbox = null;
        __mon_outbox = null;
        __model_outbox = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Build environment
    // [[ implements std_verif_pkg::env._build() ]]
    virtual protected function automatic void _build();
        trace_msg("_build()");
        driver.inbox = __drv_inbox;
        model.inbox = __model_inbox;
        model.outbox = __model_outbox;
        monitor.outbox = __mon_outbox;
        scoreboard.got_inbox = __mon_outbox;
        scoreboard.exp_inbox = __model_outbox;
        register_subcomponent(driver);
        register_subcomponent(monitor);
        register_subcomponent(model);
        register_subcomponent(scoreboard);
        trace_msg("_build() Done.");
    endfunction

    // Environment process (run loop)
    // [[ implements std_verif_pkg::component._run() ]]
    protected task _run();
        trace_msg("_run()");
        super._run();
        forever begin
            TRANSACTION_IN_T transaction;
            trace_msg("Running...");
            inbox.get(transaction);
            __drv_inbox.put(transaction);
            __model_inbox.put(transaction);
        end
        trace_msg("_run() Done.");
    endtask

endclass : component_env
