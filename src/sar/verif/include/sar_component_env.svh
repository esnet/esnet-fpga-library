// Packet component testbench environment base class
class sar_component_env #(
    parameter type BUF_ID_T = bit,
    parameter type OFFSET_T = bit,
    parameter type META_T = bit
) extends std_verif_pkg::basic_env;

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_component_env";

    typedef sar_frame_transaction#(BUF_ID_T) FRAME_T;
    typedef sar_segment_transaction#(BUF_ID_T,OFFSET_T) SEGMENT_T;

    //===================================
    // Properties
    //===================================
    sar_sequencer#(BUF_ID_T,OFFSET_T) sequencer;
    sar_segment_driver#(BUF_ID_T,OFFSET_T,META_T) driver;

    sar_segment_monitor#(BUF_ID_T,OFFSET_T,META_T) monitor;
    sar_collector#(BUF_ID_T,OFFSET_T) collector;

    std_verif_pkg::model#(FRAME_T) model;
    std_verif_pkg::scoreboard#(FRAME_T) scoreboard;

    mailbox #(FRAME_T)  inbox;

    local mailbox #(FRAME_T)   __seq_inbox;
    local mailbox #(FRAME_T)   __model_inbox;
    local mailbox #(SEGMENT_T) __seg_in_pipe;
    local mailbox #(SEGMENT_T) __seg_out_pipe;
    local mailbox #(FRAME_T)   __model_outbox;
    local mailbox #(FRAME_T)   __coll_outbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="sar_component_env"
        );
        super.new(name);

        inbox = new();
        __seq_inbox = new();
        __model_inbox = new();
        __seg_in_pipe = new();
        __seg_out_pipe = new();
        __model_outbox = new();
        __coll_outbox = new();

        this.sequencer = new("sequencer");
        this.driver = new("seg_driver");
        this.monitor = new("seg_monitor");
        this.collector = new("collector");

        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        model = null;
        scoreboard = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        sequencer = null;
        driver = null;
        monitor = null;
        collector = null;
        model = null;
        scoreboard = null;

        inbox = null;
        __seq_inbox = null;
        __model_inbox = null;
        __seg_in_pipe = null;
        __seg_out_pipe = null;
        __model_outbox = null;
        __coll_outbox = null;

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
        sequencer.inbox = __seq_inbox;
        sequencer.outbox = __seg_in_pipe;
        driver.inbox = __seg_in_pipe;
        model.inbox = __model_inbox;
        model.outbox = __model_outbox;
        monitor.outbox = __seg_out_pipe;
        collector.inbox = __seg_out_pipe;
        collector.outbox = __coll_outbox;
        scoreboard.got_inbox = __coll_outbox;
        scoreboard.exp_inbox = __model_outbox;
        register_subcomponent(sequencer);
        register_subcomponent(driver);
        register_subcomponent(monitor);
        register_subcomponent(collector);
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
            FRAME_T frame;
            trace_msg("Running...");
            inbox.get(frame);
            __seq_inbox.put(frame);
            __model_inbox.put(frame);
        end
        trace_msg("_run() Done.");
    endtask

endclass : sar_component_env
