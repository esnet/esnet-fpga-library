// SAR model
// - passes non-errored frames to the expected output
// - drops frames with the error bit set (they will never be reassembled)
class sar_model #(
    parameter type BUF_ID_T = bit
) extends std_verif_pkg::model #(
    sar_frame_transaction#(BUF_ID_T),
    sar_frame_transaction#(BUF_ID_T)
);

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_model";

    //===================================
    // Typedefs
    //===================================
    typedef sar_frame_transaction#(BUF_ID_T) FRAME_T;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="sar_model");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.inbox  = null;
        this.outbox = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Model run loop
    // [[ overrides std_verif_pkg::model._run() ]]
    // WORKAROUND: xsim fails to access private base-class fields (__cnt_in, __cnt_out)
    // of parameterized model specialisations when _run() executes in a forked thread.
    // Overriding here keeps all field accesses local.
    protected task _run();
        FRAME_T transaction;
        forever begin
            inbox.get(transaction);
            _process(transaction);
        end
    endtask

    // Pass clean frames; drop errored ones.
    // [[ implements std_verif_pkg::model._process() ]]
    protected task _process(input FRAME_T transaction);
        trace_msg("_process()");
        if (transaction.error) begin
            debug_msg($sformatf("Dropping errored frame buf_id=0x%0x.", transaction.buf_id));
            _drop(transaction);
        end else begin
            debug_msg($sformatf("Passing frame buf_id=0x%0x.", transaction.buf_id));
            _enqueue(transaction);
        end
        trace_msg("_process() Done.");
    endtask

endclass : sar_model
