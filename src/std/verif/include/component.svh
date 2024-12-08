// Base component class for verification
// - abstract class (can't be instantiated directly)
// - describes interface for 'generic' components, where methods are to be implemented by subclass
virtual class component extends base;

    local static const string __CLASS_NAME = "std_verif_pkg::component";

    //===================================
    // Properties
    //===================================
    local component __SUBCOMPONENTS[$];
    local event __start;
    local event __stop;
    local semaphore __LOCK;
    local bit __FINALIZE = 1'b0;
    local bit __AUTOSTART = 1'b1;
    local bit __RUNNING;

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Build component (instantiate subcomponents, connect interfaces, etc.)
    pure virtual protected function automatic void _build();
    // Reset component state
    pure virtual function automatic void _reset();
    // Quiesce all interfaces
    pure virtual protected task _idle();
    // Perform any necessary initialization, etc. and block until component is ready for processing
    pure virtual protected task _init();
    // Start component execution
    pure virtual protected task _run();

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="component");
        super.new(name);
        __reset();
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        trace_msg("destroy()");
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].destroy();
        __SUBCOMPONENTS.delete();
        __LOCK = null;
        super.destroy();
        trace_msg("destroy() Done.");
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set log verbosity
    // [[ overrides std_verif_pkg::base.set_debug_level() ]]
    function automatic void set_debug_level(input int DEBUG_LEVEL);
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].set_debug_level(DEBUG_LEVEL);
        super.set_debug_level(DEBUG_LEVEL);
    endfunction

    function automatic void enable_autostart();
        __AUTOSTART = 1'b1;
    endfunction

    function automatic void disable_autostart();
        __AUTOSTART = 1'b0;
    endfunction

    // Initialize lock
    local function automatic void __init_lock();
        __LOCK = new(1);
    endfunction

    // Acquire exclusive lock (blocking)
    task lock();
        __LOCK.get();
    endtask

    // Relinquish lock
    function automatic void unlock();
        if (__LOCK.try_get()) error_msg("Unlock attempted but no lock set.");
        __LOCK.put();
    endfunction

    // Register subcomponents
    function automatic void register_subcomponent(const ref component SUBCOMPONENT);
        __SUBCOMPONENTS.push_back(SUBCOMPONENT);
    endfunction

    // Build component (connect interfaces, etc.)
    function automatic void build();
        trace_msg("build()");
        _build();
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].build();
        trace_msg("build() Done.");
    endfunction

    // Finalize (register component for destruction/cleanup)
    function automatic void finalize();
        __FINALIZE = 1'b1;
    endfunction

    // Reset base component object state
    local function automatic void __reset();
        __init_lock();
    endfunction

    // Reset component state
    function automatic void reset();
        trace_msg("reset()");
        _reset();
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].reset();
        __reset();
        trace_msg("reset() Done.");
    endfunction

    // Quiesce all interfaces
    virtual task idle();
        trace_msg("idle()");
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].idle();
        _idle();
        trace_msg("idle() Done.");
    endtask

    // Initialize component (and block until ready for processing) 
    virtual task init();
        trace_msg("init()");
        _init();
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].init();
        trace_msg("init() Done.");
    endtask

    // Start component execution (run loop)
    virtual task run();
        trace_msg("run()");
        if (__RUNNING) stop();
        fork
            begin
                fork
                    begin
                        autostart();
                        wait(__start.triggered);
                        _run();
                        wait(0); 
                    end
                    begin
                        wait(__stop.triggered);
                    end
                join_any
                disable fork;
            end
        join_none;
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].run();
        trace_msg("run() Done.");
    endtask

    // Start component execution
    function automatic void start();
        trace_msg("start()");
        -> __start;
        __RUNNING = 1'b1;
        trace_msg("start() Done.");
    endfunction

    // Auto-start for component and subcomponents
    function automatic void autostart();
        if (__AUTOSTART) begin
            start();
            foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].autostart();
        end
    endfunction

    // Stop component execution
    function automatic void stop();
        trace_msg("stop()");
        -> __stop;
        foreach (__SUBCOMPONENTS[i]) __SUBCOMPONENTS[i].stop();
        __RUNNING = 1'b0;
        if (__FINALIZE) destroy();
        trace_msg("stop() Done.");
    endfunction

endclass : component
